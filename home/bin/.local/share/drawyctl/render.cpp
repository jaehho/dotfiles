// build-extra: -fPIC -lzstd
//
// -fPIC: Arch's Qt 6 exports protected symbols (QByteArray::_empty), and
// the compiler's default -fPIE makes copy relocations to them that ld
// rejects. Qt's CMake config adds it; a plain compiler line has to.
// -lzstd: ZSTD_getFrameContentSize, to vet a frame before Drawy does.
//
// drawy-render: render a Drawy board headlessly with Drawy's own code.
//
// It links the installed libdrawygui, builds the scene Drawy holds after
// File > Open, and writes what File > Export writes (PNG, SVG), plus a
// JSON report of where every item sits on the canvas. drawyctl
// (../../bin/drawyctl) builds it on demand:
//
//   ${CXX:-g++} -std=c++20 -O2 -Wall -Wextra -DDRAWY_VERSION='"1.0.2"'
//     -I<drawy clone at v1.0.2>/src/gui -I/usr/include/DrawyCore
//     $(pkg-config --cflags Qt6Gui) render.cpp -o drawy-render
//     -ldrawygui $(pkg-config --libs Qt6Gui) <build-extra above>
//
// Headers come from a clone at the installed version's tag, because
// /usr/include/DrawyCore lacks properties/property.hpp and
// transformhandlerutils.hpp. libdrawygui_export.h is the installed one.
//
// usage: drawy-render INPUT [--png OUT] [--svg OUT] [--boxes OUT|-]
//          [--scale S] [--region X,Y,W,H] [--bg COLOR] --fonts-dir DIR
// INPUT is a path or - (stdin), as a zstd frame or plain JSON. Any OUT
// may be - (stdout), but only one of them.
// --scale and --region apply to the PNG only; the SVG is exactly
// Drawy's.
// --boxes lists every kept item in document pre-order with its input
// path ("3.1" = child 1 of top-level item 3), canvas rect and rotated
// quad, and every input item Drawy would not keep under "dropped".
// Non-finite coordinates come out as JSON null (Qt's encoding).
// Exit: 0 ok, 1 cannot write an output, input over drawy-render's own
// 1 GiB limit, or internal error, 2 usage error, 3 unreadable input or
// input Drawy cannot load. Failures print one line on
// stderr. Qt and Drawy log messages are swallowed unless
// DRAWY_RENDER_VERBOSE is set.
//
// Citations are file:line in the Drawy source at the tag, under src/.
#include <cmath>
#include <cstdio>
#include <exception>
#include <memory>
#include <optional>
#include <unordered_map> // item.hpp:106 uses it without including it

#include <zstd.h>

#include <QCommandLineParser>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QImage>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QPainter>
#include <QScreen>
#include <QXmlStreamWriter>

#include "common/utils/compression.hpp"
#include "item/group.hpp"
#include "item/item.hpp"
#include "item/itemutils.hpp"
#include "serializer/deserializeutils.hpp"
#include "serializer/svgserializer.hpp"

#ifndef DRAWY_VERSION
#error "build with -DDRAWY_VERSION='\"x.y.z\"', the installed libdrawygui version"
#endif

using namespace Qt::Literals::StringLiterals;
using ItemPtr = std::shared_ptr<Item>;

namespace
{
enum Exit : int {
    ExitOk = 0,
    ExitError = 1, // an output cannot be written, a limit of this tool, or an internal error
    ExitUsage = 2,
    ExitInput = 3,
};

// Thrown to end the run with one line on stderr.
struct Failure {
    int code;
    QString message;
};

[[noreturn]] void fail(int code, const QString &message)
{
    throw Failure{code, message};
}

void warn(const QString &message)
{
    std::fprintf(stderr, "drawy-render: warning: %s\n", qUtf8Printable(message));
}

QtMessageHandler g_qtHandler = nullptr;

// Drawy logs a warning for every missing key it defaults (for example
// itemdeserializer.cpp:45-53), so a hand-written board would otherwise
// fill stderr. Fatal messages still go through, and Qt then aborts.
void quietMessages(QtMsgType type, const QMessageLogContext &context, const QString &message)
{
    if (type == QtFatalMsg && g_qtHandler) {
        g_qtHandler(type, context, message);
    }
}

struct Options {
    QString input;
    QString png;
    QString svg;
    QString boxes;
    QString fontsDir;
    qreal scale = 1;
    std::optional<QRectF> region;
    // Drawy's light canvas, BackgroundColorLight
    // (config/drawyglobalconfig.kcfg:50-52). The dark one is #121212
    // (:53-55); uicontext.cpp:119-125 picks one from the palette, which a
    // headless run does not have.
    QColor bg{0xf8, 0xf9, 0xfa};
};

qreal parseNumber(const QString &text, const QString &option)
{
    bool ok = false;
    const qreal value = text.trimmed().toDouble(&ok);
    if (!ok || !std::isfinite(value)) {
        fail(ExitUsage, u"--%1: not a finite number: %2"_s.arg(option, text));
    }
    return value;
}

std::optional<Options> parseOptions(const QStringList &arguments)
{
    QCommandLineParser parser;
    parser.setApplicationDescription(u"Render a Drawy board with the installed libdrawygui (Drawy %1)."_s.arg(QString::fromUtf8(DRAWY_VERSION)));
    const QCommandLineOption help({u"h"_s, u"help"_s}, u"Show this help."_s);
    const QCommandLineOption png(u"png"_s, u"Write a PNG the way File > Export does."_s, u"out"_s);
    const QCommandLineOption svg(u"svg"_s, u"Write an SVG the way File > Export does (ignores --scale, --region)."_s, u"out"_s);
    const QCommandLineOption boxes(u"boxes"_s, u"Write the item box report as JSON (- for stdout)."_s, u"out"_s);
    const QCommandLineOption scale(u"scale"_s, u"PNG: multiply the output pixel size by S (default 1)."_s, u"s"_s);
    const QCommandLineOption region(u"region"_s, u"PNG: export this canvas rect instead of the union of all items."_s, u"x,y,w,h"_s);
    const QCommandLineOption bg(u"bg"_s, u"Canvas colour (default #f8f9fa, Drawy's light canvas; dark is #121212)."_s, u"color"_s);
    const QCommandLineOption fontsDir(u"fonts-dir"_s, u"Directory with FuzzyBubbles.ttf and Inter.ttf (required)."_s, u"dir"_s);
    parser.addOptions({help, png, svg, boxes, scale, region, bg, fontsDir});
    parser.addPositionalArgument(u"input"_s, u"Board: a .drawy (zstd) or plain JSON file, or - for stdin."_s);

    if (!parser.parse(arguments)) {
        fail(ExitUsage, parser.errorText());
    }
    if (parser.isSet(help)) {
        std::fputs(qUtf8Printable(parser.helpText()), stdout);
        return std::nullopt;
    }

    Options o;
    const QStringList positional = parser.positionalArguments();
    if (positional.size() != 1) {
        fail(ExitUsage, u"expected exactly one INPUT (a path or -), got %1"_s.arg(positional.size()));
    }
    o.input = positional.constFirst();
    if (!parser.isSet(fontsDir)) {
        fail(ExitUsage, u"--fonts-dir is required (the directory holding FuzzyBubbles.ttf and Inter.ttf)"_s);
    }
    o.fontsDir = parser.value(fontsDir);
    o.png = parser.value(png);
    o.svg = parser.value(svg);
    o.boxes = parser.value(boxes);
    if ((o.png == u"-"_s) + (o.svg == u"-"_s) + (o.boxes == u"-"_s) > 1) {
        fail(ExitUsage, u"only one output can go to stdout"_s);
    }
    if (parser.isSet(scale)) {
        o.scale = parseNumber(parser.value(scale), u"scale"_s);
        if (o.scale <= 0) {
            fail(ExitUsage, u"--scale must be positive"_s);
        }
    }
    if (parser.isSet(region)) {
        const QStringList parts = parser.value(region).split(u',');
        if (parts.size() != 4) {
            fail(ExitUsage, u"--region wants X,Y,W,H"_s);
        }
        const QRectF r{parseNumber(parts[0], u"region"_s),
                       parseNumber(parts[1], u"region"_s),
                       parseNumber(parts[2], u"region"_s),
                       parseNumber(parts[3], u"region"_s)};
        if (r.width() <= 0 || r.height() <= 0) {
            fail(ExitUsage, u"--region width and height must be positive"_s);
        }
        o.region = r;
    }
    if (parser.isSet(bg)) {
        o.bg = QColor::fromString(parser.value(bg));
        if (!o.bg.isValid()) {
            fail(ExitUsage, u"--bg: not a colour: %1"_s.arg(parser.value(bg)));
        }
    }
    return o;
}

// MainWindow::loadCustomFonts (widgets/window/window.cpp:114-125) runs
// before any board loads. It must: a TEXT box is measured with
// QFontMetricsF while it is deserialized (textdeserializer.cpp:17-23,
// text.cpp:38-47, 314-322), in "Fuzzy Bubbles" (text.cpp:373-380).
// The clone's TTFs are the ones compiled into libdrawywidgets.
void registerFonts(const QString &dir)
{
    for (const QString &name : {u"FuzzyBubbles.ttf"_s, u"Inter.ttf"_s}) {
        const QString path = dir + u'/' + name;
        if (!QFileInfo(path).isFile()) {
            fail(ExitUsage, u"--fonts-dir: no %1 in %2"_s.arg(name, dir));
        }
        if (QFontDatabase::addApplicationFont(path) == -1) {
            fail(ExitUsage, u"--fonts-dir: Qt cannot load %1"_s.arg(path));
        }
    }
}

QByteArray readInput(const QString &input)
{
    QFile file;
    bool opened = false;
    if (input == u"-"_s) {
        opened = file.open(stdin, QIODevice::ReadOnly);
    } else {
        file.setFileName(input);
        opened = file.open(QIODevice::ReadOnly);
    }
    if (!opened) {
        fail(ExitInput, u"cannot open %1: %2"_s.arg(input, file.errorString()));
    }
    QByteArray data = file.readAll();
    if (file.error() != QFileDevice::NoError) {
        fail(ExitInput, u"cannot read %1: %2"_s.arg(input, file.errorString()));
    }
    return data;
}

// Drawy decompresses every file with Compression::decompressData
// (loadjob.cpp:39-42), which needs one zstd frame that states its
// content size (compression.cpp:27-48). Drawy does not catch its throw,
// so a bad frame aborts the app; here it is an input error. Plain JSON
// is accepted as well, for tools.
QJsonObject parseBoard(const QByteArray &raw)
{
    // decompressData zero-fills whatever the frame header claims
    // (compression.cpp:29, 39). A claim of 2^63 or more becomes a negative
    // QByteArray size, and ZSTD_decompress then writes past it: a forged
    // frame segfaulted Drawy in a test. Below that Drawy would try, but
    // this tool keeps its own cap, so a forged claim cannot fill the RAM.
    constexpr unsigned long long drawyMax = 1ULL << 63;
    constexpr unsigned long long maxContent = 1ULL << 30;
    static constexpr char zstdMagic[] = {'\x28', '\xb5', '\x2f', '\xfd'};

    QByteArray json = raw;
    if (raw.startsWith(QByteArrayView(zstdMagic, sizeof zstdMagic))) {
        const unsigned long long size = ZSTD_getFrameContentSize(raw.constData(), raw.size());
        const bool known = size != ZSTD_CONTENTSIZE_ERROR && size != ZSTD_CONTENTSIZE_UNKNOWN;
        if (known && size >= drawyMax) {
            fail(ExitInput, u"zstd frame claims %1 bytes of content, which Drawy cannot allocate"_s.arg(size));
        }
        if (known && size > maxContent) {
            fail(ExitError, u"zstd frame claims %1 bytes of content; drawy-render refuses more than 1 GiB (its own limit; Drawy would try)"_s.arg(size));
        }
        try {
            json = Common::Utils::Compression::decompressData(raw);
        } catch (const std::exception &e) {
            fail(ExitInput, u"invalid zstd frame: %1"_s.arg(QString::fromUtf8(e.what())));
        }
    }

    // loadjob.cpp:43-49 and deserializejob.cpp:19-30: Drawy loads nothing
    // for unparsable JSON, a non-object root, or an empty object.
    QJsonParseError error{};
    const QJsonDocument doc = QJsonDocument::fromJson(json, &error);
    if (doc.isNull()) {
        fail(ExitInput, u"invalid JSON at byte %1: %2"_s.arg(error.offset).arg(error.errorString()));
    }
    if (!doc.isObject()) {
        fail(ExitInput, u"JSON root is not an object"_s);
    }
    if (doc.object().isEmpty()) {
        fail(ExitInput, u"JSON root is an empty object, which Drawy refuses to load"_s);
    }
    return doc.object();
}

// FreeformDeserializer::deserialize reads pressures[i] for every point
// i (freeformdeserializer.cpp:26-33) without checking the length, which
// reads past the array. Pad with 0, which is what Drawy was seen to load.
// Returns value with every FREEFORM in it padded; warns once per item.
QJsonValue padPressures(const QJsonValue &value, const QString &path)
{
    if (!value.isObject()) {
        return value;
    }
    QJsonObject obj = value.toObject();
    const QString type = obj.value(u"type"_s).toString();
    if (type == u"FREEFORM"_s) {
        const qsizetype points = obj.value(u"points"_s).toArray().size();
        QJsonArray pressures = obj.value(u"pressures"_s).toArray();
        if (pressures.size() < points) {
            const QString counts = u"%1 points but %2 pressures"_s.arg(points).arg(pressures.size());
            warn(u"item %1: FREEFORM has %2; Drawy reads past the array there, drawn with pressure 0"_s.arg(path, counts));
            while (pressures.size() < points) {
                pressures.append(0.0);
            }
            obj[u"pressures"_s] = pressures;
        }
    } else if (type == u"GROUP"_s && obj.value(u"items"_s).isArray()) {
        QJsonArray children = obj.value(u"items"_s).toArray();
        for (qsizetype i = 0; i < children.size(); ++i) {
            children[i] = padPressures(children.at(i), path + u'.' + QString::number(i));
        }
        obj[u"items"_s] = children;
    }
    return obj;
}

// Whether DeserializeUtils::deserializeItems keeps this element. It
// decides on "type" alone, plus the plugin keys for CUSTOM
// (deserializeutils.cpp:21-40), so asking it about a copy holding only
// those keys gives its answer without building the whole item.
bool deserializes(const QJsonValue &value)
{
    const QJsonObject obj = value.toObject();
    QJsonObject skeleton;
    for (const QString &key : {u"type"_s, u"pluginName"_s, u"customObjectName"_s}) {
        if (obj.contains(key)) {
            skeleton[key] = obj.value(key);
        }
    }
    return !DeserializeUtils::deserializeItems(QJsonArray{skeleton}).isEmpty();
}

// Why deserializeItems skipped this element.
QString deserializeProblem(const QJsonValue &value)
{
    if (!value.isObject()) {
        return u"not a JSON object"_s;
    }
    const QJsonObject obj = value.toObject();
    if (!obj.contains(u"type"_s)) {
        return u"no \"type\""_s;
    }
    if (!obj.value(u"type"_s).isString()) {
        return u"\"type\" is not a string"_s;
    }
    const QString type = obj.value(u"type"_s).toString();
    switch (ItemUtils::convertItemTypeStringToEnum(type)) {
    case Item::FormType::Invalid:
        return u"unknown type \"%1\" (types are case-sensitive)"_s.arg(type);
    case Item::FormType::Custom: {
        const QString plugin = obj.value(u"pluginName"_s).toString();
        const QString shape = obj.value(u"customObjectName"_s).toString();
        return u"no installed plugin shape \"%1\"/\"%2\" (pluginName/customObjectName)"_s.arg(plugin, shape);
    }
    default:
        return u"Drawy built nothing for type \"%1\""_s.arg(type);
    }
}

// The root rect of Drawy's QuadTree. While the root holds fewer items
// than its capacity of 10000 (spatialcontext.cpp:23), this rect alone
// decides whether an item is kept. It starts as the canvas size hint,
// which is the screen size (canvas.cpp:14), and only grows.
class QuadTreeRoot
{
public:
    explicit QuadTreeRoot(const QRectF &start)
        : m_box(start)
    {
    }

    // QuadTree::insertItem (quadtree.cpp:52-65): grow to contain the four
    // corners of box, then keep the item if the tree intersects box. This
    // runs Qt's own QRectF code, so edge cases come out as they do in
    // Drawy. Zero width or height (or a width lost to rounding at huge
    // coordinates) is a null rect, which intersects nothing. Infinite
    // and NaN extents pass, as a real Drawy run showed for an item scaled
    // by 1e308.
    bool insert(const QRectF &box)
    {
        for (const QPointF &p : {box.topLeft(), box.topRight(), box.bottomRight(), box.bottomLeft()}) {
            expand(p);
        }
        return m_box.intersects(box);
    }

private:
    // QuadTree::expand (quadtree.cpp:225-285), on the root rect alone:
    // double towards p until the rect contains it. A NaN coordinate passes
    // QRectF::contains, so this always ends; the cap is only a guard.
    void expand(const QPointF &p)
    {
        for (int i = 0; i < 4096 && !m_box.contains(p); ++i) {
            const qreal w = m_box.width();
            const qreal h = m_box.height();
            if (p.x() < m_box.left() || p.y() < m_box.top()) {
                m_box.adjust(-w, -h, 0, 0);
            } else if (p.x() > m_box.right() || p.y() > m_box.bottom()) {
                m_box.adjust(0, 0, w, h);
            } else {
                break; // unreachable: !contains means one test above holds
            }
        }
    }

    QRectF m_box;
};

// LoadJobUtil::loadFile's processItem (widgets/jobs/loadjobutil.cpp:21-38)
// without the bookkeeping. A group folds its transform into its children
// (group.cpp:76-89). Each child is processed, which inserts it into the
// tree; the tree drops it again at :30-32, but its growth stays. The
// group's transform is then reset, and regrouping moves the group to the
// top-left of its children's union (group.cpp:50-67). Returns whether
// the tree kept item. A top-level item it refuses is not drawn,
// exported or saved.
bool processItem(const ItemPtr &item, QuadTreeRoot &tree)
{
    if (item->formType() == Item::FormType::Group) {
        auto group = std::static_pointer_cast<GroupItem>(item);
        const QList<ItemPtr> children = group->unGroup();
        for (const auto &child : children) {
            processItem(child, tree);
        }
        group->setTransform({});
        group->group(children);
    }
    return tree.insert(item->boundingBox());
}

// Why the tree refused this top-level item.
QString refusal(const Item &item)
{
    const QRectF box = item.boundingBox();
    if (item.formType() == Item::FormType::Group) {
        if (static_cast<const GroupItem &>(item).items().isEmpty()) {
            return u"empty group"_s;
        }
        return u"group bounding box has zero area (e.g. its children are empty TEXT, or it has no transform)"_s;
    }
    return u"bounding box %1 x %2 has zero area, which QuadTree::insert refuses"_s.arg(box.width()).arg(box.height());
}

QJsonObject rectJson(const QRectF &r)
{
    return {{u"x"_s, r.x()}, {u"y"_s, r.y()}, {u"w"_s, r.width()}, {u"h"_s, r.height()}};
}

QJsonObject dropJson(const QString &path, const QString &reason)
{
    return {{u"path"_s, path}, {u"reason"_s, reason}};
}

// The scene as Drawy holds it after File > Open, and its box report.
struct Scene {
    QList<ItemPtr> items; // top-level items in the quadtree, bottom first
    QJsonArray boxes; // report "items", document pre-order
    QJsonArray dropped; // report "dropped"
};

// Appends item (and its children) to scene.boxes. source is the input
// JSON the item came from; path its input indices; parentWorld maps its
// parent's space to the canvas (identity at top level).
void describe(const ItemPtr &item, const QJsonObject &source, const QString &path, const QTransform &parentWorld, bool topLevel, Scene &scene)
{
    // A child's transform applies first, then its group's: GroupItem::draw
    // composes it onto the painter (group.cpp:12-20), as unGroup does
    // (group.cpp:78-82). Qt's a * b applies a, then b.
    const QTransform world = item->transformObj() * parentWorld;
    const QRectF local = item->normalizedBoundingBox();
    const QPolygonF quad{world.map(local.topLeft()), world.map(local.topRight()), world.map(local.bottomRight()), world.map(local.bottomLeft())};
    // Top level: what the quadtree stores and the export unites
    // (item.cpp:25-28, group.cpp:91-94).
    const QRectF rect = topLevel ? item->boundingBox() : quad.boundingRect();

    QJsonArray corners;
    for (const QPointF &p : quad) {
        corners.append(QJsonArray{p.x(), p.y()});
    }
    QJsonObject entry{
        {u"path"_s, path},
        {u"id"_s, QString::fromLatin1(item->id())},
        {u"type"_s, ItemUtils::convertItemTypeEnumToString(item->formType())},
        {u"rect"_s, rectJson(rect)},
        {u"quad"_s, corners},
    };
    if (item->formType() == Item::FormType::Text) {
        entry[u"text_size"_s] = QJsonObject{{u"w"_s, local.width()}, {u"h"_s, local.height()}};
    }
    scene.boxes.append(entry);

    if (item->formType() != Item::FormType::Group) {
        return;
    }
    // The group holds the children deserializeItems kept, in input order
    // (groupdeserializer.cpp:26-29); walk the input to recover indices.
    const QList<ItemPtr> children = std::static_pointer_cast<GroupItem>(item)->items();
    const QJsonArray sources = source.value(u"items"_s).toArray();
    qsizetype next = 0;
    for (qsizetype i = 0; i < sources.size(); ++i) {
        const QString childPath = path + u'.' + QString::number(i);
        if (!deserializes(sources.at(i))) {
            scene.dropped.append(dropJson(childPath, deserializeProblem(sources.at(i))));
            continue;
        }
        if (next == children.size()) {
            fail(ExitError, u"internal: group %1 has fewer children than its input"_s.arg(path));
        }
        describe(children.at(next++), sources.at(i).toObject(), childPath, world, false, scene);
    }
    if (next != children.size()) {
        fail(ExitError, u"internal: group %1 has more children than its input"_s.arg(path));
    }
}

// DeserializeJob::deserializeItems + LoadJobUtil::loadFile.
Scene loadScene(const QJsonObject &root)
{
    // deserializejob.cpp:46: a missing or non-array "items" is an empty board.
    const QJsonValue itemsValue = root.value(u"items"_s);
    if (!itemsValue.isArray()) {
        warn(u"\"items\" is missing or not an array; Drawy loads this as an empty board"_s);
    }
    const QJsonArray input = itemsValue.toArray();

    // A fresh session's tree. In the app it also keeps the growth of
    // earlier loads in the session (spatialcontext.cpp:58-63 only clears
    // items), which can matter only for non-finite boxes.
    const QScreen *screen = QGuiApplication::primaryScreen();
    QuadTreeRoot tree{QRectF{QPointF{0, 0}, screen ? QSizeF{screen->size()} : QSizeF{1920, 1080}}};

    Scene scene;
    for (qsizetype i = 0; i < input.size(); ++i) {
        const QString path = QString::number(i);
        // deserializeItems treats elements independently, so one call per
        // element keeps the input index.
        const QJsonValue value = padPressures(input.at(i), path);
        const QList<ItemPtr> made = DeserializeUtils::deserializeItems(QJsonArray{value});
        if (made.isEmpty()) {
            scene.dropped.append(dropJson(path, deserializeProblem(value)));
            continue;
        }
        const ItemPtr item = made.constFirst();
        if (!processItem(item, tree)) {
            scene.dropped.append(dropJson(path, refusal(*item)));
            continue;
        }
        // Stacking order is insertion order: OrderedList::insert hands out
        // last + 1 (orderedlist.cpp:37-53) and getAllItems sorts by it
        // (quadtree.cpp:138-143, 168-176). "zorder" is never read.
        scene.items.append(item);
        describe(item, value.toObject(), path, QTransform{}, true, scene);
    }
    return scene;
}

// Union of the top-level boxes, as exportToImage and writeSvg compute it
// (actionmanager.cpp:584-589, svgserializer.cpp:27-31).
QRectF unionOf(const QList<ItemPtr> &items)
{
    QRectF box;
    for (const auto &item : items) {
        box |= item->boundingBox();
    }
    return box;
}

std::unique_ptr<QFile> openOutput(const QString &path)
{
    auto file = std::make_unique<QFile>();
    bool opened = false;
    if (path == u"-"_s) {
        opened = file->open(stdout, QIODevice::WriteOnly);
    } else {
        file->setFileName(path);
        opened = file->open(QIODevice::WriteOnly | QIODevice::Truncate);
    }
    if (!opened) {
        fail(ExitError, u"cannot write %1: %2"_s.arg(path, file->errorString()));
    }
    return file;
}

void closeOutput(QFile &file, const QString &path)
{
    if (!file.flush() || file.error() != QFileDevice::NoError) {
        fail(ExitError, u"cannot write %1: %2"_s.arg(path, file.errorString()));
    }
    file.close();
}

// ActionManager::exportToImage's PNG branch (actionmanager.cpp:583-611).
// With --scale 1 and no --region the calls are the same.
void writePng(const Scene &scene, const Options &o)
{
    const QRectF area = o.region ? *o.region : unionOf(scene.items);
    if (area.isNull()) {
        fail(ExitInput, u"nothing to render: the board has no items Drawy keeps (pass --region)"_s);
    }
    if (!std::isfinite(area.width() * o.scale) || !std::isfinite(area.height() * o.scale)) {
        fail(ExitInput, u"the board's bounding box is not finite (pass --region)"_s);
    }

    // QSizeF::toSize() rounds, so a fractional edge row can be lost
    // (actionmanager.cpp:591), as in Drawy.
    const QSize size = (area.size() * o.scale).toSize();
    QImage image(size, QImage::Format_ARGB32);
    if (image.isNull()) {
        const bool fromArguments = o.region || o.scale != 1;
        fail(fromArguments ? ExitUsage : ExitInput, u"cannot make a %1 x %2 px image"_s.arg(size.width()).arg(size.height()));
    }
    image.fill(o.bg);

    QPainter painter(&image);
    painter.setRenderHints(QPainter::Antialiasing | QPainter::SmoothPixmapTransform);
    if (o.scale != 1) {
        painter.scale(o.scale, o.scale);
    }
    QTransform t{};
    t.translate(area.topLeft().x(), area.topLeft().y());
    painter.setTransform(t.inverted(), true);
    for (const auto &item : scene.items) {
        painter.save();
        painter.setTransform(item->transformObj(), true);
        item->draw(painter, QPointF{0, 0});
        painter.restore();
    }
    painter.end();

    auto file = openOutput(o.png);
    if (!image.save(file.get(), "PNG")) {
        fail(ExitError, u"cannot write %1: PNG encoding failed"_s.arg(o.png));
    }
    closeOutput(*file, o.png);
}

// ActionManager::exportToImage's SVG branch (actionmanager.cpp:578-582).
// SvgPaintDevice reports 72 DPI (serializer/svgpaintdevice.cpp:287-289)
// while text boxes are measured at the screen's 96, so Drawy's SVG text
// comes out 25% small. That is kept.
void writeSvg(const Scene &scene, const Options &o)
{
    auto file = openOutput(o.svg);
    {
        QXmlStreamWriter stream(file.get());
        stream.setAutoFormatting(true);
        SvgSerializer::writeSvg(stream, scene.items, o.bg);
        if (stream.hasError()) {
            fail(ExitError, u"cannot write %1"_s.arg(o.svg));
        }
    }
    closeOutput(*file, o.svg);
}

void writeBoxes(const Scene &scene, const Options &o)
{
    const QScreen *screen = QGuiApplication::primaryScreen();
    const QRectF canvas = unionOf(scene.items);
    const QJsonObject report{
        {u"drawy_version"_s, QString::fromUtf8(DRAWY_VERSION)},
        // QFontMetricsF resolves TEXT point sizes against this
        // (18 pt = 24 px at 96), so text_size depends on it.
        {u"dpi"_s, screen ? screen->logicalDotsPerInchY() : 96.0},
        {u"canvas"_s, scene.items.isEmpty() ? QJsonValue{} : QJsonValue{rectJson(canvas)}},
        {u"items"_s, scene.boxes},
        {u"dropped"_s, scene.dropped},
    };
    auto file = openOutput(o.boxes);
    file->write(QJsonDocument(report).toJson(QJsonDocument::Indented));
    closeOutput(*file, o.boxes);
}

int run(const QStringList &arguments)
{
    const std::optional<Options> options = parseOptions(arguments);
    if (!options) {
        return ExitOk;
    }
    const Options &o = *options;
    registerFonts(o.fontsDir);
    const Scene scene = loadScene(parseBoard(readInput(o.input)));
    if (!o.boxes.isEmpty()) {
        writeBoxes(scene, o);
    }
    if (!o.svg.isEmpty()) {
        writeSvg(scene, o);
    }
    if (!o.png.isEmpty()) {
        writePng(scene, o);
    }
    return ExitOk;
}
} // namespace

int main(int argc, char *argv[])
{
    if (qEnvironmentVariableIsEmpty("DRAWY_RENDER_VERBOSE")) {
        g_qtHandler = qInstallMessageHandler(quietMessages);
    }
    if (qEnvironmentVariableIsEmpty("QT_QPA_PLATFORM")) {
        qputenv("QT_QPA_PLATFORM", "offscreen");
    }
    // In libdrawygui only Common::Utils::Freehand::updateSettings reads
    // Drawy's settings (common/utils/freehand.cpp:14-15), and only
    // libdrawywidgets calls it (widgets/context/applicationcontext.cpp:36).
    // drawy-render never does, so FREEFORM strokes use the built-in
    // thinning 0.5 (Pressure Sensitivity) whatever drawyrc says, and
    // drawyrc is never opened. The name is insurance: should a later
    // libdrawygui open its config on a path run here, KConfig would look
    // for a drawyctl-renderrc, not drawyrc.
    QCoreApplication::setApplicationName(u"drawyctl-render"_s);
    QGuiApplication app(argc, argv);

    try {
        return run(QCoreApplication::arguments());
    } catch (const Failure &f) {
        std::fprintf(stderr, "drawy-render: %s\n", qUtf8Printable(f.message));
        return f.code;
    } catch (const std::exception &e) {
        // std::bad_alloc from Qt, for example, under a memory limit.
        std::fprintf(stderr, "drawy-render: %s\n", e.what());
        return ExitError;
    }
}

# Contributing

## Before Making Changes

1. Read [README.md](README.md) to understand the system
2. Check [ISSUES.md](ISSUES.md) for known issues
3. Understand the architecture (see above)

## Making Changes

### Adding a New Step

1. Add to `scripts/converge.sh` step array
2. Create `step_<name>()` function
3. Add error handling (decide)
4. Test with `./scripts/converge.sh system` or `user`

### Modifying Existing Steps

- **System steps**: require root, run at boot
- **User steps**: run as owner, at login + daily
- Check `state/decisions.json` for previous decisions

### Adding New Config Files

- System configs → `system/`
- User configs → `home/`
- Scripts → `scripts/`

## Testing

```bash
# Test a specific step
sudo ./scripts/converge.sh system boot
./scripts/converge.sh user stow

# Full run (follows output)
./scripts/converge.sh now
```

## Git Workflow

1. Make changes
2. Commit with clear message
3. Push and let converge run on machines
4. Check `state/decisions.json` for errors

## Best Practices

- Keep it simple (ponytail mode)
- One file, one purpose
- Document decisions in comments
- Test before committing

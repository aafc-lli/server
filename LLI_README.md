# LLI NextCloud Fork

This is a fork of the NextCloud repo to which customizations are applied to meet LLI requirements.

We use Git Submodules to manage additional repositories involved in our NextCloud deployment. This includes:
- Our theme, `cdsp-theme`
- Our app, `cdsp`
- Several apps from the NextCloud ecosystem

# Instruction Manual

To clone this repo, run:

```bash
git clone --recurse-submodules <repo url>
```

Clone this repo in the same directory as the `lli-infra` repo to allow the scripts in that repo to function properly.

For example:
```
lli/
    lli-infra/
    server/
```

*Document incomplete*

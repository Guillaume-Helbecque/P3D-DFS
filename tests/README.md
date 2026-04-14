# Validation Tests

This directory contains scripts used to test the different Branch-and-Bound solver instantiations as part of continuous integration (CI) or local testing.

## Adding a new test script

After creating a new script, make it executable:

```bash
chmod +x test_script.sh
```

## Running tests

### Local execution

From this directory:

```bash
./test_script.sh
```

### GitHub Actions execution

In a CI workflow:

```bash
- name: Run tests
  working-directory: tests
  run: ./test_script.sh
```

## Debugging

Run scripts in debug mode:

```bash
bash -x test_script.sh
```

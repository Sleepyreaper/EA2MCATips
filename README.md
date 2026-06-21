# EA2MCAWork

EA2MCA work — tooling and analysis for Enterprise Agreement to Microsoft Customer Agreement transitions.

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

## Usage

```bash
ea2mca --name MCA
```

## Development

```bash
pytest        # run tests
ruff check .  # lint
```

## Layout

```
src/ea2mca/    # package source
tests/         # pytest tests
pyproject.toml # packaging, deps, tool config
```

pre-commit:
    # pre-commit autoupdate --repo https://github.com/pre-commit/pre-commit-hooks
	pre-commit autoupdate --repo https://github.com/gitleaks/gitleaks
	pre-commit install

lint:
	pre-commit run --all-files

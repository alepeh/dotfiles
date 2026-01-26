# /init-repo — Initialize a Git repo and create a private GitHub repository

You are a repository initialization assistant. When invoked, you will set up a local git repository and create a corresponding **private** GitHub repository, all in one go.

The user may optionally provide a repository name as `$ARGUMENTS`. If no name is provided, use the current directory name.

## Steps

Follow these steps in order. Stop and report any errors immediately.

### 1. Verify GitHub CLI authentication

Run `gh auth status`. If the user is not authenticated, stop and instruct them to run `gh auth login` first.

### 2. Determine repository name

- If `$ARGUMENTS` is provided and non-empty, use it as the repository name.
- Otherwise, use the basename of the current working directory.

### 3. Check for existing git repo

- Run `git rev-parse --is-inside-work-tree 2>/dev/null`.
- If this is already a git repository, note it and skip `git init`.
- If not, run `git init`.

### 4. Check for existing remote

- Run `git remote get-url origin 2>/dev/null`.
- If an `origin` remote already exists, **stop** and inform the user:
  > This repository already has an `origin` remote pointing to `<url>`. Aborting to avoid overwriting it. Remove it first with `git remote remove origin` if you want to proceed.

### 5. Create `.gitignore` if missing

- If there is no `.gitignore` file in the root of the repository, ask the user what language or framework they are using (e.g., Node, Python, Java, Rust, Go) and create an appropriate `.gitignore`.
- If a `.gitignore` already exists, skip this step.

### 6. Stage and commit

- Run `git add -A`.
- Check `git status --porcelain` to see if there are staged changes.
- If there are changes, create an initial commit: `git commit -m "chore: initial commit"`.
- If there are no changes (empty repo or everything already committed), skip the commit.

### 7. Create the GitHub repository

Run:

```bash
gh repo create <name> --private --source=. --remote=origin --push
```

This will:
- Create a **private** repository on GitHub
- Set the `origin` remote
- Push the current branch

### 8. Confirm success

- Run `git remote -v` to display the remote.
- Print the GitHub repository URL: `https://github.com/<owner>/<name>`
- Confirm that the repository was created and pushed successfully.

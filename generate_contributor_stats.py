import subprocess
import re
import os
from collections import defaultdict

# Mapping of aliases to canonical names
ALIASES = {
    "Adrian": "Adrian Gierakowski",
    "matthewcroughan": "Matthew Croughan",
    "Max": "Max Headroom",
    "Lodjuret": "lodjuret",
}

# Known GitHub usernames
GITHUB_HANDLES = {
    "Adrian Gierakowski": "adrian-gierakowski",
    "Matthew Croughan": "MatthewCroughan",
    "Eelco Dolstra": "edolstra",
    "arcnmx": "arcnmx",
    "Gerg-L": "Gerg-L",
    "Karpfen": "Karpfen",
}

def get_log_stats():
    # Run git log to get stats, excluding flake-modules/packages
    # We use pathspecs to exclude the directory
    cmd = ["git", "log", "--numstat", "--format=AUTHOR:%aN <%aE>", "--", ".", ":(exclude)flake-modules/packages"]
    result = subprocess.run(cmd, capture_output=True, text=True, errors="replace")

    if result.returncode != 0:
        print(f"Error running git log: {result.stderr}")
        return {}

    stats = defaultdict(lambda: {"commits": 0, "added": 0, "deleted": 0, "email": set()})
    current_author = None

    for line in result.stdout.splitlines():
        if line.startswith("AUTHOR:"):
            author_raw = line[7:].strip()
            # Parse name and email
            match = re.match(r"(.*) <(.*)>", author_raw)
            if match:
                name, email = match.groups()
                # Apply aliases
                if name in ALIASES:
                    name = ALIASES[name]

                current_author = name
                stats[current_author]["commits"] += 1
                stats[current_author]["email"].add(email)
        elif line.strip():
            # Numstat line: added deleted filename
            parts = line.split()
            if len(parts) == 3:
                added, deleted, _ = parts
                if added != "-":
                    stats[current_author]["added"] += int(added)
                if deleted != "-":
                    stats[current_author]["deleted"] += int(deleted)

    return stats

def get_blame_stats():
    # Get all tracked files excluding flake-modules/packages
    cmd = ["git", "ls-files", ".", ":(exclude)flake-modules/packages"]
    result = subprocess.run(cmd, capture_output=True, text=True, errors="replace")

    if result.returncode != 0:
        print(f"Error running git ls-files: {result.stderr}")
        return {}

    files = result.stdout.splitlines()
    surviving_stats = defaultdict(int)

    for filepath in files:
        if not os.path.isfile(filepath):
            continue

        # Run git blame
        # -w ignores whitespace changes
        # --line-porcelain gives easy to parse format
        cmd = ["git", "blame", "--line-porcelain", "-w", filepath]
        result = subprocess.run(cmd, capture_output=True, text=True, errors="replace")

        if result.returncode != 0:
            # File might be binary or not tracked (shouldn't happen with ls-files but safe to check)
            continue

        for line in result.stdout.splitlines():
            if line.startswith("author "):
                author = line[7:].strip()
                # Apply aliases
                if author in ALIASES:
                    author = ALIASES[author]
                surviving_stats[author] += 1

    return surviving_stats

def generate_markdown(log_stats, blame_stats):
    # Merge stats keys
    all_authors = set(log_stats.keys()) | set(blame_stats.keys())

    # Authors to display
    authors_data = []

    for author in all_authors:
        # Skip bots
        if author == "Hercules CI Effects" or author == "google-labs-jules[bot]":
            continue

        log_data = log_stats.get(author, {"commits": 0, "added": 0, "deleted": 0, "email": set()})
        surviving_lines = blame_stats.get(author, 0)

        # Determine GitHub handle
        handle = GITHUB_HANDLES.get(author, "")
        if not handle:
            # Try to infer from email if it's a noreply address
            for email in log_data["email"]:
                if "noreply.github.com" in email:
                    # Format: ID+username@...
                    match = re.search(r"\d+\+([^@]+)@", email)
                    if match:
                        handle = match.group(1)
                        break
                    else:
                         # older format: username@...
                        match = re.search(r"([^@]+)@users.noreply.github.com", email)
                        if match:
                             handle = match.group(1)
                             break

        authors_data.append({
            "name": author,
            "handle": handle,
            "commits": log_data["commits"],
            "added": log_data["added"],
            "deleted": log_data["deleted"],
            "surviving": surviving_lines
        })

    # Sort by surviving lines, then commits
    sorted_authors = sorted(authors_data, key=lambda x: (x["surviving"], x["commits"]), reverse=True)

    md = "| Contributor | GitHub Handle | Commits | Lines Added | Lines Deleted | Surviving Lines |\n"
    md += "|---|---|---|---|---|---|\n"

    for data in sorted_authors:
        handle_str = f"@{data['handle']}" if data['handle'] else ""

        # Skip if no surviving lines (as per request to only track code currently in the repo)
        if data['surviving'] == 0:
            continue

        # Skip "Not Committed Yet" which comes from git blame on uncommitted changes
        if data['name'] == "Not Committed Yet":
            continue

        md += f"| {data['name']} | {handle_str} | {data['commits']} | {data['added']} | {data['deleted']} | {data['surviving']} |\n"

    return md

if __name__ == "__main__":
    log_stats = get_log_stats()
    blame_stats = get_blame_stats()
    md = generate_markdown(log_stats, blame_stats)
    print(md)

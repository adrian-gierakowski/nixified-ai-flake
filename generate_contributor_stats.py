import subprocess
import re
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

def get_stats():
    # Run git log to get stats
    cmd = ["git", "log", "--numstat", "--format=AUTHOR:%aN <%aE>"]
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

def generate_markdown(stats):
    # Sort by number of commits
    sorted_stats = sorted(stats.items(), key=lambda x: x[1]["commits"], reverse=True)

    md = "| Contributor | GitHub Handle | Commits | Lines Added | Lines Deleted |\n"
    md += "|---|---|---|---|---|\n"

    for author, data in sorted_stats:
        handle = GITHUB_HANDLES.get(author, "")
        if not handle:
            # Try to infer from email if it's a noreply address
            for email in data["email"]:
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

        handle_str = f"@{handle}" if handle else ""
        if author == "Hercules CI Effects": # Bot
             continue
        if author == "google-labs-jules[bot]": # Me
             continue

        md += f"| {author} | {handle_str} | {data['commits']} | {data['added']} | {data['deleted']} |\n"

    return md

if __name__ == "__main__":
    stats = get_stats()
    md = generate_markdown(stats)
    print(md)

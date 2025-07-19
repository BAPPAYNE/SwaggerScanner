import googlesearch
import time
import argparse
import sys

def get_dorks(args):
    """Determines which dorks to use based on user input."""
    # Priority 1: Custom dork file
    if args.dork_file:
        try:
            with open(args.dork_file, 'r') as f:
                dorks = [line.strip() for line in f if line.strip()]
                print(f"[*] Loaded {len(dorks)} dorks from {args.dork_file}.")
                return dorks
        except FileNotFoundError:
            print(f"[ERROR] Dork file not found: {args.dork_file}", file=sys.stderr)
            sys.exit(1)

    # Priority 2: Single custom dork
    if args.dork:
        print(f"[*] Using custom dork: {args.dork}")
        return [args.dork]

    # Priority 3: Built-in dorks
    print("[*] Using built-in dorks.")
    return [
        'inurl:"/swagger-ui/index.html"',
        'intitle:"Swagger UI" (inurl:"/swagger-ui/" OR inurl:"/swagger/" OR inurl:"/api-docs/" OR inurl:"/v2/api-docs" OR inurl:"/v3/api-docs")',
        'site:*.{domain} -www',
        'intext:"Swagger UI" intitle:"Swagger UI" site:{domain}',
        'site:{domain} inurl:(swagger.json OR swagger.yaml)',
        '(inurl:api OR inurl:apis OR inurl:graphql OR inurl:swagger OR inurl:v1 OR inurl:v2) (filetype:json OR filetype:yaml) site:{domain}'
    ]

def main():
    parser = argparse.ArgumentParser(description="Google Dorking backend for Swagger Hunter.")
    parser.add_argument("-u", "--domain", type=str, help="The target domain.", default="")
    parser.add_argument("-l", "--limit", type=str, help="Number of results per dork.", default="")
    parser.add_argument("-o", "--output", type=str, help="Output file.", required=True)
    parser.add_argument("-d", "--dork", type=str, help="A single custom dork string.")
    parser.add_argument("--dork-file", type=str, help="File with a list of dorks.")
    parser.add_argument("--append", action="store_true", help="Append to the output file instead of overwriting.")
    args = parser.parse_args()

    target_site = args.domain.strip()
    limit = int(args.limit.strip()) if args.limit.strip().isdigit() else None
    
    # Get the list of dorks to run
    dork_templates = get_dorks(args)

    # Prepare final dorks by formatting them with the domain if provided
    final_dorks = []
    for dork in dork_templates:
        # Replace {domain} placeholder or append site: filter
        if '{domain}' in dork and target_site:
            final_dorks.append(dork.format(domain=target_site))
        elif target_site:
            final_dorks.append(f"{dork} site:{target_site}")
        else:
            # If no domain, don't add dorks that require one
            if '{domain}' not in dork:
                final_dorks.append(dork)
    
    final_dorks = list(dict.fromkeys(final_dorks)) # Remove duplicates

    if not final_dorks:
        print("[!] No applicable dorks to run for the given configuration.", file=sys.stderr)
        return

    # Determine file mode
    file_mode = "a" if args.append else "w"
    
    try:
        with open(args.output, file_mode, encoding='utf-8') as f:
            if file_mode == 'w' or f.tell() == 0:
                f.write(f"# Swagger Hunter Results\n")
            
            f.write(f"\n# === Target: {'All Websites' if not target_site else target_site} ===\n")

            for i, dork in enumerate(final_dorks):
                print(f"\n[*] Running Dork {i+1}/{len(final_dorks)}: {dork}")
                f.write(f"--- Dork: {dork} ---\n")
                
                try:
                    search_results = googlesearch.search(dork, stop=limit, pause=4.0)
                    found_results = False
                    for result in search_results:
                        print(result)
                        f.write(result + "\n")
                        found_results = True
                    if not found_results:
                        print("No results found.")
                        f.write("No results found.\n")

                except Exception as e:
                    error_message = f"[ERROR] Could not perform search: {e}"
                    print(error_message, file=sys.stderr)
                    f.write(f"{error_message}\n")
                    if "429" in str(e):
                        print("[!] Rate-limited by Google. Pausing for 60 seconds...", file=sys.stderr)
                        time.sleep(60)
                
                f.write("\n")
                time.sleep(5)

    except Exception as e:
        print(f"[CRITICAL] A fatal error occurred: {e}", file=sys.stderr)

if __name__ == "__main__":
    main()
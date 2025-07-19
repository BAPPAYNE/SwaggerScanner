# google_dorker.py
import time
import argparse
import sys
import yaml
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError


def load_credentials(args):
    """
    Loads credentials, prioritizing command-line args over the config file.
    Returns a tuple: (api_key, cse_id)
    """
    if args.api_key and args.cse_id:
        print("[*] Using API credentials provided via command-line flags.")
        return args.api_key, args.cse_id
    
    try:
        with open('config.yaml', 'r') as f:
            config = yaml.safe_load(f)
            if config and 'google_api' in config:
                api_key = config['google_api'].get('api_key')
                cse_id = config['google_api'].get('cse_id')
                
                if api_key and cse_id:
                    print("[*] Loaded API credentials from config.yaml.")
                    return api_key.strip(), cse_id.strip()

    except FileNotFoundError:
        pass
    except (yaml.YAMLError, AttributeError) as e:
        print(f"[ERROR] Could not parse config.yaml. Please check its format. Details: {e}", file=sys.stderr)
        return None, None
        
    return None, None

def get_dorks(args):
    """Determines which dorks to use based on user input."""
    if args.dork_file:
        try:
            with open(args.dork_file, 'r') as f:
                dorks = [line.strip() for line in f if line.strip()]
                print(f"[*] Loaded {len(dorks)} dorks from {args.dork_file}.")
                return dorks
        except FileNotFoundError:
            print(f"[ERROR] Dork file not found: {args.dork_file}", file=sys.stderr)
            sys.exit(1)

    if args.dork:
        print(f"[*] Using custom dork: {args.dork}")
        return [args.dork]

    print("[*] Using built-in dorks.")
    return [
        'inurl:"/swagger-ui/index.html"',
        'intitle:"Swagger UI" (inurl:"/swagger-ui/" OR inurl:"/swagger/" OR inurl:"/api-docs/" OR inurl:"/v2/api-docs")',
        'site:*.{domain} -www',
        'intext:"Swagger UI" intitle:"Swagger UI" site:{domain}',
        'site:{domain} inurl:(swagger.json OR swagger.yaml)',
        '(inurl:api OR inurl:apis OR inurl:graphql OR inurl:swagger OR inurl:v1 OR inurl:v2) (filetype:json OR filetype:yaml) site:{domain}'
    ]

def main():
    parser = argparse.ArgumentParser(description="Google Dorking backend for Swagger Hunter (API Edition).")
    parser.add_argument("-k", "--api-key", type=str, help="Your Google API Key (overrides config.yaml).")
    parser.add_argument("-c", "--cse-id", type=str, help="Your Programmable Search Engine ID (overrides config.yaml).")
    parser.add_argument("-u", "--domain", type=str, help="The target domain.", default="")
    # --- CHANGE IS HERE: Updated default value and help text ---
    parser.add_argument("-l", "--limit", type=str, help="Total results per dork (Default: 100, which is the API maximum).", default="100")
    parser.add_argument("-o", "--output", type=str, help="Output file.", required=True)
    parser.add_argument("-d", "--dork", type=str, help="A single custom dork string.")
    parser.add_argument("--dork-file", type=str, help="File with a list of dorks.")
    parser.add_argument("--append", action="store_true", help="Append to the output file.")
    args = parser.parse_args()
    api_key, cse_id = load_credentials(args)

    if not api_key or not cse_id:
        print("[ERROR] Credentials not found.", file=sys.stderr)
        print("Please either create a valid 'config.yaml' file or provide credentials using the -k and -c flags.", file=sys.stderr)
        sys.exit(1)
    
    try:
        service = build("customsearch", "v1", developerKey=api_key)
    except Exception as e:
        print(f"[CRITICAL] Failed to build Google API service. Check API key and dependencies. Error: {e}", file=sys.stderr)
        sys.exit(1)

    target_site = args.domain.strip()
    limit = int(args.limit) if args.limit.strip().isdigit() else 100 # Default to 100 if input is invalid
    limit = min(limit, 100) # Ensure the limit never exceeds the API's max of 100

    dork_templates = get_dorks(args)
    final_dorks = [dork.format(domain=target_site) if '{domain}' in dork else (f"{dork} site:{target_site}" if target_site else dork) for dork in dork_templates if '{domain}' not in dork or target_site]
    final_dorks = list(dict.fromkeys(final_dorks))

    file_mode = "a" if args.append else "w"
    
    with open(args.output, file_mode, encoding='utf-8') as f:
        if file_mode == 'w' or f.tell() == 0: f.write(f"# Swagger Hunter Results (API) | by BAPPAYNE\n")
        f.write(f"\n# === Target: {'All Websites' if not target_site else target_site} ===\n")

        for i, dork in enumerate(final_dorks):
            print(f"\n[*] Running Dork {i+1}/{len(final_dorks)}: {dork}")
            f.write(f"--- Dork: {dork} ---\n")
            
            try:
                found_items = []
                start_index = 1
                while len(found_items) < limit:
                    num_to_get = min(10, limit - len(found_items))
                    res = service.cse().list(q=dork, cx=cse_id, num=num_to_get, start=start_index).execute()

                    if 'items' in res:
                        found_items.extend(res['items'])
                    else:
                        break

                    queries = res.get('queries', {})
                    if 'nextPage' in queries:
                        start_index = queries['nextPage'][0]['startIndex']
                    else:
                        break

                if found_items:
                    for item in found_items:
                        link = item.get('link')
                        print(link)
                        f.write(f"{link}\n")
                else:
                    print("No results found.")
                    f.write("No results found.\n")

            except HttpError as e:
                error_message = f"[ERROR] API error occurred: {e.content.decode('utf-8')}"
                print(error_message, file=sys.stderr)
                f.write(f"{error_message}\n")
                if 'quota' in str(e).lower():
                    print("[!] Daily quota likely exceeded. Aborting.", file=sys.stderr)
                    break 
            
            f.write("\n")
            time.sleep(1)

if __name__ == "__main__":
    main()
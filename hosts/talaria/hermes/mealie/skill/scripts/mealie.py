#!/usr/bin/env python3
"""Read selected Mealie REST resources using only Python's standard library."""

import argparse
from datetime import date
import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode, urlsplit, urlunsplit
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener
from uuid import UUID


MAX_RESPONSE_BYTES = 8 * 1024 * 1024


class MealieError(Exception):
    """An error safe to display without exposing credentials or response bodies."""


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # urllib otherwise forwards Authorization when following redirects.
        raise MealieError("Mealie redirected the request; configure its direct base URL.")


def bounded_integer(minimum, maximum):
    def parse(value):
        try:
            number = int(value)
        except ValueError:
            raise argparse.ArgumentTypeError("Expected an integer.") from None
        if not minimum <= number <= maximum:
            raise argparse.ArgumentTypeError(f"Expected {minimum} through {maximum}.")
        return number

    return parse


def iso_date(value):
    try:
        parsed = date.fromisoformat(value)
        if parsed.isoformat() != value:
            raise ValueError
    except ValueError:
        raise argparse.ArgumentTypeError("Use a date in YYYY-MM-DD format.") from None
    return value


def recipe_identifier(value):
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,255}", value):
        raise argparse.ArgumentTypeError("Use a recipe slug or ID, without URL components.")
    return value


def shopping_list_identifier(value):
    try:
        return str(UUID(value))
    except ValueError:
        raise argparse.ArgumentTypeError("Use a shopping list UUID.") from None


def arguments(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("check", help="Check authenticated access without printing account data.")
    recipes = commands.add_parser("recipes", help="List or search recipes.")
    recipes.add_argument("--search")
    recipe = commands.add_parser("recipe", help="Read full recipe ingredients and instructions.")
    recipe.add_argument("identifier", type=recipe_identifier)
    mealplans = commands.add_parser("mealplans", help="Read saved meal plans.")
    mealplans.add_argument("--start-date", type=iso_date)
    mealplans.add_argument("--end-date", type=iso_date)
    lists = commands.add_parser("shopping-lists", help="List household shopping lists.")
    shopping_list = commands.add_parser("shopping-list", help="Read a shopping list and its items.")
    shopping_list.add_argument("identifier", type=shopping_list_identifier)
    for command in (recipes, mealplans, lists):
        command.add_argument("--page", type=bounded_integer(1, 100000), default=1)
        command.add_argument("--per-page", type=bounded_integer(1, 100), default=20)
    args = parser.parse_args(argv)
    if args.command == "mealplans" and args.start_date and args.end_date:
        if args.start_date > args.end_date:
            parser.error("--start-date must be on or before --end-date.")
    return args


def endpoint(args):
    paths = {
        "check": "/api/users/self",
        "recipes": "/api/recipes",
        "recipe": "/api/recipes/",
        "mealplans": "/api/households/mealplans",
        "shopping-lists": "/api/households/shopping/lists",
        "shopping-list": "/api/households/shopping/lists/",
    }
    path = paths[args.command]
    if args.command in ("recipe", "shopping-list"):
        path += args.identifier
    query = {}
    if args.command in ("recipes", "mealplans", "shopping-lists"):
        query = {"page": args.page, "perPage": args.per_page}
    if args.command == "recipes" and args.search:
        query["search"] = args.search
    if args.command == "mealplans":
        for key in ("start_date", "end_date"):
            value = getattr(args, key)
            if value:
                query[key] = value
    return path, query


def credentials():
    base_url = os.environ.get("MEALIE_BASE_URL", "").strip()
    token = os.environ.get("MEALIE_API_TOKEN", "").strip()
    if not base_url or not token:
        raise MealieError("Set MEALIE_BASE_URL and MEALIE_API_TOKEN in the hermes-mealie-env agenix secret.")
    try:
        parts = urlsplit(base_url)
        # Access .port to validate malformed or out-of-range ports too.
        parts.port
        valid = (
            parts.scheme in ("http", "https") and parts.hostname
            and not parts.username and not parts.password
            and not parts.query and not parts.fragment
            and not any(char.isspace() for char in base_url)
        )
    except ValueError:
        valid = False
    if not valid:
        raise MealieError("MEALIE_BASE_URL must be an HTTP(S) base URL without credentials, query, or fragment.")
    if parts.path.rstrip("/").endswith("/api"):
        raise MealieError("MEALIE_BASE_URL must be the application base URL, without /api.")
    if token.lower().startswith("bearer ") or any(char.isspace() for char in token) or "<" in token:
        raise MealieError("MEALIE_API_TOKEN must contain the raw token, without a Bearer prefix or placeholder.")
    return parts, token


def read_resource(parts, token, path, query):
    url = urlunsplit((parts.scheme, parts.netloc, parts.path.rstrip("/") + path, urlencode(query), ""))
    request = Request(url, headers={"Authorization": "Bearer " + token, "Accept": "application/json"}, method="GET")
    # Connect directly to the configured service; ignore ambient HTTP proxies.
    opener = build_opener(ProxyHandler({}), NoRedirects())
    try:
        with opener.open(request, timeout=20) as response:
            body = response.read(MAX_RESPONSE_BYTES + 1)
    except HTTPError as error:
        status = error.code
        error.close()
        hints = {
            401: "Token rejected; check or regenerate the Mealie API token.",
            403: "Access denied; check the token user's group and household permissions.",
            404: "Resource or API route not found; check the identifier and your Mealie version.",
        }
        raise MealieError(f"Mealie returned HTTP {status}. " + hints.get(status, "Request failed.")) from None
    except (URLError, TimeoutError, OSError, ValueError):
        raise MealieError("Could not connect to Mealie; check the URL, TLS certificate, and Tailscale access.") from None
    if len(body) > MAX_RESPONSE_BYTES:
        raise MealieError("Mealie response exceeded 8 MiB; use a smaller page.")
    try:
        return json.loads(body)
    except (ValueError, UnicodeDecodeError):
        raise MealieError("Mealie returned invalid JSON; check the base URL and API route.") from None


def main(argv=None):
    args = arguments(argv)
    try:
        parts, token = credentials()
        path, query = endpoint(args)
        result = read_resource(parts, token, path, query)
        if args.command == "check":
            result = {"ok": True, "message": "Authenticated Mealie access works."}
        # Redact even if a response happens to contain the token in a data field.
        output = json.dumps(result, ensure_ascii=False, indent=2)
        print(output.replace(token, "[redacted]"))
        return 0
    except MealieError as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

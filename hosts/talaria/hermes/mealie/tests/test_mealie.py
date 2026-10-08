"""Exercise the client against a mock server, including credential boundaries."""

from contextlib import redirect_stderr, redirect_stdout
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import importlib.util
import io
import json
import os
from pathlib import Path
import threading
import unittest
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit


CLIENT_PATH = Path(__file__).parents[1] / "skill/scripts/mealie.py"
SPEC = importlib.util.spec_from_file_location("mealie", CLIENT_PATH)
client = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(client)
TOKEN = "dummy-mealie-token"
LIST_ID = "0beedb26-cea5-4245-8069-234a48fb2f42"


class MockMealie(BaseHTTPRequestHandler):
    requests = []
    status = 200
    body = {"data": [{"name": "Chicken soup"}], "total_pages": 2}
    redirect = ""

    def do_GET(self):
        type(self).requests.append((self.path, self.headers.get("Authorization")))
        self.send_response(type(self).status)
        if type(self).redirect:
            self.send_header("Location", type(self).redirect)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        body = type(self).body
        self.wfile.write(body if isinstance(body, bytes) else json.dumps(body).encode())

    def log_message(self, *args):
        pass


class MealieTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), MockMealie)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.url = f"http://127.0.0.1:{cls.server.server_port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    def setUp(self):
        MockMealie.requests = []
        MockMealie.status = 200
        MockMealie.body = {"data": [{"name": "Chicken soup"}], "total_pages": 2}
        MockMealie.redirect = ""

    def run_client(self, argv, **env):
        configured = {"MEALIE_BASE_URL": self.url, "MEALIE_API_TOKEN": TOKEN, **env}
        stdout, stderr = io.StringIO(), io.StringIO()
        with patch.dict(os.environ, configured, clear=True), redirect_stdout(stdout), redirect_stderr(stderr):
            status = client.main(argv)
        return status, stdout.getvalue(), stderr.getvalue()

    def test_recipe_search_encodes_query_and_sends_bearer_header(self):
        status, stdout, stderr = self.run_client(["recipes", "--search", "chicken & rice", "--page", "2", "--per-page", "5"])
        self.assertEqual((status, stderr), (0, ""))
        path, authorization = MockMealie.requests[0]
        self.assertEqual(authorization, "Bearer " + TOKEN)
        self.assertEqual(urlsplit(path).path, "/api/recipes")
        self.assertEqual(parse_qs(urlsplit(path).query), {"search": ["chicken & rice"], "page": ["2"], "perPage": ["5"]})
        self.assertEqual(json.loads(stdout)["total_pages"], 2)

    def test_detail_and_collection_routes(self):
        examples = [
            (["recipe", "chicken-soup"], "/api/recipes/chicken-soup"),
            (["shopping-lists"], "/api/households/shopping/lists"),
            (["shopping-list", LIST_ID], "/api/households/shopping/lists/" + LIST_ID),
            (["mealplans", "--start-date", "2026-10-07", "--end-date", "2026-10-13"], "/api/households/mealplans"),
        ]
        for argv, expected_path in examples:
            with self.subTest(argv=argv):
                self.assertEqual(self.run_client(argv)[0], 0)
                path = urlsplit(MockMealie.requests[-1][0])
                self.assertEqual(path.path, expected_path)
                if argv[0] == "mealplans":
                    self.assertEqual(parse_qs(path.query)["start_date"], ["2026-10-07"])
                    self.assertEqual(parse_qs(path.query)["end_date"], ["2026-10-13"])

    def test_check_omits_account_details(self):
        MockMealie.body = {"email": "private@example.test", "id": "account-id"}
        status, stdout, _ = self.run_client(["check"])
        self.assertEqual(status, 0)
        self.assertEqual(MockMealie.requests[0][0], "/api/users/self")
        self.assertTrue(json.loads(stdout)["ok"])
        self.assertNotIn("private@example.test", stdout)

    def test_missing_or_invalid_configuration_sends_no_request(self):
        for env in [
            {"MEALIE_API_TOKEN": ""},
            {"MEALIE_API_TOKEN": "Bearer " + TOKEN},
            {"MEALIE_BASE_URL": "http://user:password@example.test"},
            {"MEALIE_BASE_URL": self.url + "/api"},
            {"MEALIE_BASE_URL": self.url + "?token=" + TOKEN},
            {"MEALIE_BASE_URL": "http://localhost:bad-port"},
        ]:
            with self.subTest(env=env):
                status, stdout, stderr = self.run_client(["check"], **env)
                self.assertEqual(status, 1)
                self.assertEqual(stdout, "")
                self.assertNotIn(TOKEN, stderr)
        self.assertEqual(MockMealie.requests, [])

    def test_redirect_never_receives_token(self):
        MockMealie.status = 302
        MockMealie.redirect = self.url + "/credential-recipient"
        status, _, stderr = self.run_client(["check"])
        self.assertEqual(status, 1)
        self.assertIn("redirected", stderr)
        self.assertEqual(len(MockMealie.requests), 1)

    def test_http_errors_do_not_echo_response_body(self):
        for code in (401, 403, 404, 500):
            with self.subTest(code=code):
                MockMealie.status = code
                MockMealie.body = {"detail": TOKEN}
                status, stdout, stderr = self.run_client(["recipes"])
                self.assertEqual(status, 1)
                self.assertEqual(stdout, "")
                self.assertIn(str(code), stderr)
                self.assertNotIn(TOKEN, stderr)

    def test_response_token_is_redacted(self):
        MockMealie.body = {"note": TOKEN}
        status, stdout, _ = self.run_client(["recipes"])
        self.assertEqual(status, 0)
        self.assertEqual(json.loads(stdout)["note"], "[redacted]")

    def test_bad_json_and_oversized_response(self):
        MockMealie.body = b"<html>login</html>"
        self.assertIn("invalid JSON", self.run_client(["check"])[2])
        MockMealie.body = b"x" * 100
        with patch.object(client, "MAX_RESPONSE_BYTES", 50):
            self.assertIn("exceeded", self.run_client(["recipes"])[2])

    def test_invalid_arguments_cannot_select_arbitrary_endpoints_or_methods(self):
        examples = [
            ["recipe", "../admin"], ["recipe", "%2e%2e"],
            ["recipe", "slug?extra=true"], ["shopping-list", "not-a-uuid"],
            ["recipes", "--per-page", "-1"], ["recipes", "--page", "0"],
            ["mealplans", "--start-date", "2026-02-30"],
            ["mealplans", "--start-date", "2026-10-13", "--end-date", "2026-10-07"],
            ["delete", "some-recipe"],
        ]
        for argv in examples:
            with self.subTest(argv=argv), redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    client.main(argv)
        self.assertEqual(MockMealie.requests, [])


if __name__ == "__main__":
    unittest.main()

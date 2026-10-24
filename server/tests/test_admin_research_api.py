"""Focused tests for the isolated OpenAI Responses helper.

Does not connect to OpenAI, modify user records, or use a real API key.
"""
import ast
import os
from pathlib import Path
from types import SimpleNamespace
from unittest import TestCase, mock
import unittest


def helper():
    source=Path(__file__).resolve().parents[1].joinpath("app.py").read_text()
    node=next(n for n in ast.parse(source).body
              if isinstance(n,ast.FunctionDef) and n.name=="_chat_json")
    fake_requests=SimpleNamespace(
        RequestException=Exception,
        post=mock.Mock(),
    )
    namespace={"os":os,"time":SimpleNamespace(monotonic=lambda:1),
               "requests":fake_requests,"print":lambda *a,**k:None}
    module=ast.fix_missing_locations(ast.Module(body=[node],type_ignores=[]))
    exec(compile(module,"server/app.py","exec"),namespace)
    return namespace["_chat_json"],fake_requests


def response(code,body):
    return SimpleNamespace(status_code=code,json=lambda:body)


class AdminAIResearchTests(TestCase):
    def test_missing_key_reports_real_cause(self):
        ask,requests=helper()
        with mock.patch.dict(os.environ,{"OPENAI_API_KEY":""}):
            detail={}
            self.assertIsNone(ask("test","input",diagnostics=detail))
        self.assertEqual(detail["code"],"missing_key")
        requests.post.assert_not_called()

    def test_model_fallback_returns_researched_text(self):
        ask,requests=helper()
        requests.post.side_effect=[
            response(400,{"error":{"code":"model_not_found"}}),
            response(200,{"output":[{"type":"message","content":[
                {"type":"output_text","text":'{"title":"Yashamoq"}'}]}]}),
        ]
        with mock.patch.dict(os.environ,{"OPENAI_API_KEY":"test-not-real","OPENAI_TEXT_MODEL":"obsolete"}):
            detail={}
            self.assertIn("Yashamoq",ask("test","input",web_search=True,diagnostics=detail))
        self.assertEqual(detail,{})
        self.assertEqual(requests.post.call_count,2)

    def test_invalid_key_is_not_misreported_as_no_books(self):
        ask,requests=helper()
        requests.post.return_value=response(401,{"error":{"code":"invalid_api_key"}})
        with mock.patch.dict(os.environ,{"OPENAI_API_KEY":"test-not-real"}):
            detail={}
            self.assertIsNone(ask("test","input",diagnostics=detail))
        self.assertEqual(detail["code"],"invalid_key")

    def test_spend_limit_is_not_cured_by_fallback(self):
        ask,requests=helper()
        requests.post.return_value=response(429,{"error":{"code":"insufficient_quota"}})
        with mock.patch.dict(os.environ,{"OPENAI_API_KEY":"test-not-real"}):
            detail={}
            self.assertIsNone(ask("test","input",diagnostics=detail))
        self.assertEqual(detail["code"],"quota")
        requests.post.assert_called_once()

    def test_legacy_model_does_not_get_unsupported_reasoning(self):
        ask,requests=helper()
        requests.post.return_value=response(200,{"output":[{"content":[
            {"type":"output_text","text":"{}"}]}]})
        with mock.patch.dict(os.environ,{"OPENAI_API_KEY":"test-not-real","OPENAI_TEXT_MODEL":"gpt-4.1-mini"}):
            self.assertEqual(ask("test","input",web_search=True),"{}")
        self.assertNotIn("reasoning",requests.post.call_args.kwargs["json"])
        self.assertEqual(requests.post.call_args.kwargs["json"]["tools"][0]["type"],"web_search")


if __name__=="__main__":
    unittest.main()

#!/bin/bash
# Smoke-test the exact bundled Browser Use adapter used by the Screenote skills.
# Requires: uv, Python 3.11+, Chromium/Chrome
# Usage: bash evals/browser-use-mcp-smoke.sh

set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

uv run --with "mcp==1.26.0" python - <<'PY'
import asyncio
import http.server
import json
import os
import tempfile
import threading
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

EXPECTED_TOOLS = {
    "browser_navigate",
    "browser_click",
    "browser_type",
    "browser_get_state",
    "browser_extract_content",
    "browser_get_html",
    "browser_screenshot",
    "browser_scroll",
    "browser_go_back",
    "browser_list_tabs",
    "browser_switch_tab",
    "browser_close_tab",
    "retry_with_browser_use_agent",
    "browser_list_sessions",
    "browser_close_session",
    "browser_close_all",
    "browser_set_viewport",
    "browser_page_metrics",
    "browser_scroll_to",
    "browser_screenshot_to_file",
}

VIEWPORTS = [(1280, 800), (768, 1024), (390, 844)]


class FixtureHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"""<!doctype html><html style='scroll-behavior:smooth'><body style='margin:0'>
        <div style='height:6200px;background:linear-gradient(#123,#def)'></div>
        </body></html>"""
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        return


def load_params():
    config = json.loads(Path(".mcp.json").read_text())
    browser = config["mcpServers"]["browser-use"]
    env = dict(browser.get("env", {}))
    env["BROWSER_USE_HEADLESS"] = "true"
    if executable_path := os.environ.get("BROWSER_USE_EXECUTABLE_PATH"):
        env["BROWSER_USE_EXECUTABLE_PATH"] = executable_path
    return StdioServerParameters(
        command=browser["command"],
        args=browser.get("args", []),
        env=env,
        cwd=browser.get("cwd"),
    )


def parse_json_result(result, tool_name):
    if result.isError:
        raise SystemExit(f"{tool_name} returned an MCP error: {result.content}")
    texts = [item.text for item in result.content if item.type == "text"]
    if len(texts) != 1 or texts[0].startswith("Error:"):
        raise SystemExit(f"{tool_name} returned an unexpected result: {texts}")
    return json.loads(texts[0])


async def main():
    fixture = http.server.ThreadingHTTPServer(("127.0.0.1", 0), FixtureHandler)
    fixture_thread = threading.Thread(target=fixture.serve_forever, daemon=True)
    fixture_thread.start()
    fixture_url = f"http://127.0.0.1:{fixture.server_port}/"
    params = load_params()
    profile_dirs_before = set(
        Path(tempfile.gettempdir()).glob("screenote-browser-use-*")
    )
    created_profiles = set()
    try:
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                tools = await session.list_tools()
                by_name = {tool.name: tool for tool in tools.tools}
                missing = sorted(EXPECTED_TOOLS - set(by_name))
                if missing:
                    raise SystemExit(f"Missing expected Browser Use tools: {', '.join(missing)}")

                viewport_schema = by_name["browser_set_viewport"].inputSchema
                if viewport_schema.get("required") != ["width", "height"]:
                    raise SystemExit("browser_set_viewport must require width and height")
                capture_schema = by_name["browser_screenshot_to_file"].inputSchema
                max_height = capture_schema.get("properties", {}).get("max_height", {})
                if max_height.get("maximum") != 5000 or max_height.get("default") != 5000:
                    raise SystemExit("browser_screenshot_to_file must cap captures at 5000 px")

                try:
                    for width, height in VIEWPORTS:
                        result = await session.call_tool(
                            "browser_set_viewport", {"width": width, "height": height}
                        )
                        metrics = parse_json_result(result, "browser_set_viewport")
                        if metrics.get("viewport") != {"width": width, "height": height}:
                            raise SystemExit(
                                f"Viewport verification drifted for {width}x{height}: {metrics}"
                            )

                    created_profiles = set(
                        Path(tempfile.gettempdir()).glob("screenote-browser-use-*")
                    ) - profile_dirs_before
                    if len(created_profiles) != 1:
                        raise SystemExit(
                            "Browser Use did not create exactly one ephemeral profile: "
                            f"{sorted(map(str, created_profiles))}"
                        )

                    await session.call_tool("browser_navigate", {"url": fixture_url})
                    await session.call_tool(
                        "browser_set_viewport", {"width": 390, "height": 844}
                    )
                    metrics_result = await session.call_tool("browser_page_metrics", {})
                    metrics = parse_json_result(metrics_result, "browser_page_metrics")
                    if set(metrics) != {
                        "fonts_loaded",
                        "loading_images",
                        "page",
                        "ready_state",
                        "scroll",
                        "viewport",
                    }:
                        raise SystemExit(f"browser_page_metrics exposed unexpected fields: {metrics}")
                    if metrics["page"]["height"] < 6200:
                        raise SystemExit(f"fixture height was not observed: {metrics}")

                    scroll_result = await session.call_tool("browser_scroll_to", {"y": 1234})
                    if parse_json_result(scroll_result, "browser_scroll_to")["scroll"]["y"] != 1234:
                        raise SystemExit("browser_scroll_to did not apply an exact offset")
                    scroll_result = await session.call_tool("browser_scroll_to", {"y": 0})
                    if parse_json_result(scroll_result, "browser_scroll_to")["scroll"]["y"] != 0:
                        raise SystemExit("browser_scroll_to could not return to the top")

                    with tempfile.TemporaryDirectory(prefix="screenote-mcp-smoke-") as directory:
                        output = Path(directory) / "capture.png"
                        screenshot_result = await session.call_tool(
                            "browser_screenshot_to_file",
                            {"path": str(output), "max_height": 5000},
                        )
                        screenshot = parse_json_result(
                            screenshot_result, "browser_screenshot_to_file"
                        )
                        data = output.read_bytes()
                        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                            raise SystemExit("browser_screenshot_to_file did not write a PNG")
                        if screenshot.get("size_bytes") != len(data):
                            raise SystemExit("browser_screenshot_to_file size metadata is wrong")
                        png_width = int.from_bytes(data[16:20], "big")
                        png_height = int.from_bytes(data[20:24], "big")
                        if (png_width, png_height) != (390, 5000):
                            raise SystemExit(
                                f"bounded PNG dimensions drifted: {png_width}x{png_height}"
                            )
                        if screenshot.get("cap_fired") is not True:
                            raise SystemExit("bounded tall-page capture did not report cap_fired")
                finally:
                    await session.call_tool("browser_close_all", {})
                    leaked_profiles = [path for path in created_profiles if path.exists()]
                    if leaked_profiles:
                        raise SystemExit(
                            "browser_close_all left ephemeral profiles behind: "
                            f"{sorted(map(str, leaked_profiles))}"
                        )
    finally:
        fixture.shutdown()
        fixture.server_close()
        fixture_thread.join(timeout=5)

    print("Browser Use adapter smoke passed")
    print(f"- pinned dependency: browser-use[cli]==0.13.4")
    print(f"- tools: {len(by_name)}")
    print("- verified viewports: 1280x800, 768x1024, 390x844")
    print("- navigate/exact-scroll/5000px PNG capture/profile cleanup: passed")


asyncio.run(main())
PY

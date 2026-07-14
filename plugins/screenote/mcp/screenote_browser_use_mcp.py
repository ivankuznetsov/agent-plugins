"""Browser Use MCP adapter for deterministic Screenote captures.

The upstream direct-control server is kept intact. This adapter adds the small
capture surface Screenote needs and gives every server process an ephemeral
browser profile.
"""

from __future__ import annotations

import asyncio
import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path
from typing import Any

import mcp.types as types
from browser_use.mcp.server import BrowserUseServer


MIN_VIEWPORT = 320
MAX_VIEWPORT_WIDTH = 3840
MAX_VIEWPORT_HEIGHT = 2160
MAX_CAPTURE_HEIGHT = 5000


def _env_flag(name: str, default: bool) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


class ScreenoteBrowserUseServer(BrowserUseServer):
    """Extend Browser Use with deterministic, file-backed capture tools."""

    def __init__(self, session_timeout_minutes: int = 10):
        self._screenote_profile_dir: Path | None = None
        super().__init__(session_timeout_minutes=session_timeout_minutes)

    def _setup_handlers(self) -> None:
        super()._setup_handlers()
        upstream_list_tools = self.server.request_handlers[types.ListToolsRequest]

        @self.server.list_tools()
        async def handle_list_tools(
            request: types.ListToolsRequest,
        ) -> types.ListToolsResult:
            upstream_result = await upstream_list_tools(request)
            if not isinstance(upstream_result.root, types.ListToolsResult):
                raise RuntimeError(
                    "Browser Use returned an unexpected tools/list result"
                )

            tools = list(upstream_result.root.tools)
            tools.extend(
                [
                    types.Tool(
                        name="browser_set_viewport",
                        description=(
                            "Set the active page viewport to exact CSS-pixel dimensions and "
                            "return the verified numeric page metrics."
                        ),
                        inputSchema={
                            "type": "object",
                            "properties": {
                                "width": {
                                    "type": "integer",
                                    "minimum": MIN_VIEWPORT,
                                    "maximum": MAX_VIEWPORT_WIDTH,
                                },
                                "height": {
                                    "type": "integer",
                                    "minimum": MIN_VIEWPORT,
                                    "maximum": MAX_VIEWPORT_HEIGHT,
                                },
                            },
                            "required": ["width", "height"],
                            "additionalProperties": False,
                        },
                    ),
                    types.Tool(
                        name="browser_page_metrics",
                        description=(
                            "Return numeric viewport, page, scroll, loading-image, and document "
                            "readiness metrics without exposing page text or HTML."
                        ),
                        inputSchema={
                            "type": "object",
                            "properties": {},
                            "additionalProperties": False,
                        },
                    ),
                    types.Tool(
                        name="browser_scroll_to",
                        description="Scroll the active page to an exact non-negative CSS-pixel Y offset.",
                        inputSchema={
                            "type": "object",
                            "properties": {
                                "y": {
                                    "type": "integer",
                                    "minimum": 0,
                                    "maximum": 1000000,
                                },
                            },
                            "required": ["y"],
                            "additionalProperties": False,
                        },
                    ),
                    types.Tool(
                        name="browser_screenshot_to_file",
                        description=(
                            "Capture the page from its top into a new PNG under the system temp "
                            "directory, capped to max_height CSS pixels."
                        ),
                        inputSchema={
                            "type": "object",
                            "properties": {
                                "path": {"type": "string"},
                                "max_height": {
                                    "type": "integer",
                                    "minimum": MIN_VIEWPORT,
                                    "maximum": MAX_CAPTURE_HEIGHT,
                                    "default": MAX_CAPTURE_HEIGHT,
                                },
                            },
                            "required": ["path"],
                            "additionalProperties": False,
                        },
                    ),
                ]
            )
            return types.ListToolsResult(tools=tools)

    async def _init_browser_session(
        self, allowed_domains: list[str] | None = None, **kwargs: Any
    ) -> None:
        if self.browser_session:
            return

        if self._screenote_profile_dir is None:
            self._screenote_profile_dir = Path(
                tempfile.mkdtemp(prefix="screenote-browser-use-")
            )

        try:
            await super()._init_browser_session(
                allowed_domains=allowed_domains,
                user_data_dir=str(self._screenote_profile_dir),
                headless=_env_flag("BROWSER_USE_HEADLESS", False),
                **kwargs,
            )
        except Exception:
            self._remove_profile_dir()
            raise

    async def _execute_tool(
        self, tool_name: str, arguments: dict[str, Any]
    ) -> str | list[types.TextContent | types.ImageContent]:
        if tool_name == "browser_set_viewport":
            return json.dumps(
                await self._set_viewport(
                    arguments.get("width"), arguments.get("height")
                ),
                sort_keys=True,
            )
        if tool_name == "browser_page_metrics":
            return json.dumps(await self._page_metrics(), sort_keys=True)
        if tool_name == "browser_scroll_to":
            return json.dumps(await self._scroll_to(arguments.get("y")), sort_keys=True)
        if tool_name == "browser_screenshot_to_file":
            return json.dumps(
                await self._screenshot_to_file(
                    arguments.get("path"),
                    arguments.get("max_height", MAX_CAPTURE_HEIGHT),
                ),
                sort_keys=True,
            )
        return await super()._execute_tool(tool_name, arguments)

    async def _active_session(self):
        if not self.browser_session:
            await self._init_browser_session()
        if not self.browser_session:
            raise RuntimeError("Browser Use did not create a browser session")
        return self.browser_session

    async def _page_metrics(self) -> dict[str, Any]:
        session = await self._active_session()
        cdp_session = await session.get_or_create_cdp_session(
            target_id=None, focus=False
        )
        expression = """
            JSON.stringify({
              viewport: {
                width: Math.round(window.innerWidth),
                height: Math.round(window.innerHeight)
              },
              page: {
                width: Math.round(Math.max(document.documentElement.scrollWidth, document.body?.scrollWidth || 0)),
                height: Math.round(Math.max(document.documentElement.scrollHeight, document.body?.scrollHeight || 0))
              },
              scroll: {
                x: Math.round(window.scrollX),
                y: Math.round(window.scrollY)
              },
              ready_state: document.readyState,
              loading_images: Array.from(document.images).filter((image) => !image.complete).length,
              fonts_loaded: !document.fonts || document.fonts.status === 'loaded'
            })
        """
        result = await cdp_session.cdp_client.send.Runtime.evaluate(
            params={"expression": expression, "returnByValue": True},
            session_id=cdp_session.session_id,
        )
        raw_value = result.get("result", {}).get("value")
        if not isinstance(raw_value, str):
            raise RuntimeError("Could not read numeric page metrics")
        metrics = json.loads(raw_value)
        if not isinstance(metrics, dict):
            raise RuntimeError("Browser returned malformed page metrics")
        return metrics

    async def _set_viewport(self, width: Any, height: Any) -> dict[str, Any]:
        if type(width) is not int or not MIN_VIEWPORT <= width <= MAX_VIEWPORT_WIDTH:
            raise ValueError(
                f"width must be an integer from {MIN_VIEWPORT} to {MAX_VIEWPORT_WIDTH}"
            )
        if type(height) is not int or not MIN_VIEWPORT <= height <= MAX_VIEWPORT_HEIGHT:
            raise ValueError(
                f"height must be an integer from {MIN_VIEWPORT} to {MAX_VIEWPORT_HEIGHT}"
            )

        session = await self._active_session()
        await session._cdp_set_viewport(
            width, height, device_scale_factor=1.0, mobile=False
        )
        metrics = await self._page_metrics()
        if metrics.get("viewport") != {"width": width, "height": height}:
            raise RuntimeError(
                f"Viewport verification failed: requested {width}x{height}, got {metrics.get('viewport')}"
            )
        return metrics

    async def _scroll_to(self, y: Any) -> dict[str, Any]:
        if type(y) is not int or not 0 <= y <= 1000000:
            raise ValueError("y must be an integer from 0 to 1000000")

        session = await self._active_session()
        cdp_session = await session.get_or_create_cdp_session(
            target_id=None, focus=False
        )
        await cdp_session.cdp_client.send.Runtime.evaluate(
            params={
                "expression": (
                    "window.scrollTo({left: 0, top: "
                    f"{y}, behavior: 'instant'}})"
                ),
                "returnByValue": True,
            },
            session_id=cdp_session.session_id,
        )
        metrics = await self._page_metrics()
        page_height = metrics.get("page", {}).get("height")
        viewport_height = metrics.get("viewport", {}).get("height")
        observed_y = metrics.get("scroll", {}).get("y")
        if type(page_height) is not int or type(viewport_height) is not int:
            raise RuntimeError(f"Could not verify scroll position: {metrics}")
        expected_y = min(y, max(page_height - viewport_height, 0))
        if observed_y != expected_y:
            raise RuntimeError(
                f"Scroll verification failed: requested {y}, expected {expected_y}, got {observed_y}"
            )
        return metrics

    async def _screenshot_to_file(
        self, path_value: Any, max_height: Any
    ) -> dict[str, Any]:
        if not isinstance(path_value, str) or not path_value:
            raise ValueError("path must be a non-empty absolute PNG path")
        if (
            type(max_height) is not int
            or not MIN_VIEWPORT <= max_height <= MAX_CAPTURE_HEIGHT
        ):
            raise ValueError(
                f"max_height must be an integer from {MIN_VIEWPORT} to {MAX_CAPTURE_HEIGHT}"
            )

        target = Path(path_value)
        if not target.is_absolute() or target.suffix.lower() != ".png":
            raise ValueError("path must be an absolute .png path")
        if target.exists() or target.is_symlink():
            raise FileExistsError(f"Refusing to overwrite capture path: {target}")

        temp_root = Path(tempfile.gettempdir()).resolve()
        resolved_parent = target.parent.resolve()
        try:
            resolved_parent.relative_to(temp_root)
        except ValueError as exc:
            raise ValueError(f"capture path must be below {temp_root}") from exc
        if not resolved_parent.is_dir():
            raise FileNotFoundError(
                f"capture directory does not exist: {resolved_parent}"
            )

        session = await self._active_session()
        metrics = await self._page_metrics()
        viewport = metrics.get("viewport") or {}
        page = metrics.get("page") or {}
        width = viewport.get("width")
        page_height = page.get("height")
        if (
            type(width) is not int
            or width <= 0
            or type(page_height) is not int
            or page_height <= 0
        ):
            raise RuntimeError(
                f"Invalid dimensions for capture: viewport={viewport}, page={page}"
            )

        captured_height = min(page_height, max_height)
        data = await session.take_screenshot(
            full_page=True,
            clip={"x": 0, "y": 0, "width": width, "height": captured_height},
        )
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        try:
            with os.fdopen(fd, "wb") as output:
                output.write(data)
        except Exception:
            target.unlink(missing_ok=True)
            raise

        return {
            "path": str(target),
            "size_bytes": len(data),
            "sha256": hashlib.sha256(data).hexdigest(),
            "viewport": viewport,
            "page": page,
            "captured_height": captured_height,
            "cap_fired": page_height > captured_height,
        }

    async def _close_all_sessions(self) -> str:
        try:
            return await super()._close_all_sessions()
        finally:
            self._remove_profile_dir()

    def _remove_profile_dir(self) -> None:
        if self._screenote_profile_dir is None:
            return
        profile_dir = self._screenote_profile_dir
        try:
            shutil.rmtree(profile_dir)
        except FileNotFoundError:
            pass
        except OSError as exc:
            raise RuntimeError(
                f"Could not remove ephemeral browser profile: {profile_dir}"
            ) from exc
        self._screenote_profile_dir = None

    async def run(self) -> None:
        try:
            await super().run()
        finally:
            await self._close_all_sessions()


if __name__ == "__main__":
    asyncio.run(ScreenoteBrowserUseServer().run())

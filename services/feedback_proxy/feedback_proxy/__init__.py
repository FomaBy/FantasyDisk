"""FantasyDisk feedback relay service."""

from .app import Config, FeedbackProxyApp, create_app

__all__ = ["Config", "FeedbackProxyApp", "create_app"]

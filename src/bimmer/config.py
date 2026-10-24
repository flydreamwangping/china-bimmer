#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""统一配置读取:运行时配置(config.json)的位置与加载。

- 源码运行:读项目根目录 config/config.json(随仓库一起,便于版本化管理)。
- 打包成 .app 后:仓库目录不存在,退回用户数据目录 ~/bimmer/config.json。
"""
import json
import sys
from pathlib import Path


def _config_dir() -> Path:
    if getattr(sys, "frozen", False):
        return Path.home() / "bimmer"
    # 本文件位于 src/bimmer/config.py,仓库根 = 上三级
    return Path(__file__).resolve().parents[2] / "config"


CONFIG_PATH = _config_dir() / "config.json"


def load_config() -> dict:
    """读取配置,文件缺失/损坏时返回空 dict(调用方各自兜底默认值)。"""
    try:
        with open(CONFIG_PATH, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return {}

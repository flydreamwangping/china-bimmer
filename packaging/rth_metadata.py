# PyInstaller runtime hook
# 打包后发行版元数据(METADATA/dist-info)可能缺失,bimmer_connected 在 import 时
# 会调用 importlib.metadata.version("bimmer_connected") 取 __version__,这里做降级,
# 避免导入即崩溃。
import importlib.metadata as _im

if not getattr(_im, "_bimmer_patched", False):
    _orig_version = _im.version

    def _version(dist_name):
        try:
            return _orig_version(dist_name)
        except _im.PackageNotFoundError:
            return "0.17.4"

    _im.version = _version
    _im._bimmer_patched = True

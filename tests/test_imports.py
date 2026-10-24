"""包导入冒烟测试:确认重构后的模块都能被正常导入。"""


def test_import_package_modules():
    import bimmer.app
    import bimmer.geocode
    import bimmer.login
    import bimmer.login_sms

    assert bimmer.app.BimmerApp is not None
    assert callable(bimmer.app.main)
    assert callable(bimmer.geocode.reverse_geocode)
    assert isinstance(bimmer.login.MOBILE, str)
    assert callable(bimmer.login.x_headers)
    assert callable(bimmer.login_sms.login_sms)


def test_version():
    import bimmer

    assert bimmer.__version__ == "1.0.1"

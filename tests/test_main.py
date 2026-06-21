from ea2mca.main import greet


def test_greet_default():
    assert greet() == "Hello, world! EA2MCA project is ready."


def test_greet_name():
    assert greet("MCA") == "Hello, MCA! EA2MCA project is ready."

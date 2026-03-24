"""Password generation utilities."""

import secrets
import string


def generate_password(length: int = 20) -> str:
    """
    Generate a secure random password.

    Args:
        length: Password length (default 20 characters)

    Returns:
        Random password with alphanumeric characters
    """
    alphabet = string.ascii_letters + string.digits
    return ''.join(secrets.choice(alphabet) for _ in range(length))

"""Set a new login password for a boutique account.

Passwords are stored as bcrypt hashes (one-way), so they can't be read back -
this script replaces the hash with one for the new password you type.
"""

import getpass

from sqlalchemy import select

from app.database import SessionLocal
from app.models import User
from app.security import hash_password


def main():
    db = SessionLocal()
    try:
        users = db.scalars(select(User).order_by(User.id)).all()
        if not users:
            print("No accounts yet. Create one in the app first.")
            return
        print("Accounts:")
        for u in users:
            print(f"  - {u.username}  ({u.boutique_name})")
        print()

        username = input("Username to reset: ").strip().lower()
        user = db.scalar(select(User).where(User.username == username))
        if user is None:
            print(f"No account named '{username}'.")
            return

        password = getpass.getpass("New password (min 6 characters, hidden while typing): ")
        if len(password) < 6:
            print("Too short - nothing changed.")
            return
        if getpass.getpass("Type it again: ") != password:
            print("Passwords don't match - nothing changed.")
            return

        user.password_hash = hash_password(password)
        db.commit()
        print(f"\nDone. '{username}' can now log in with the new password.")
    finally:
        db.close()


if __name__ == "__main__":
    main()

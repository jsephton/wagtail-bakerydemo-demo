#!/bin/sh
set -e

until psql "$DATABASE_URL" -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - continuing"

# Run migrations when starting the app server. The Dockerfile's CMD is "uwsgi"
# (resolved via PATH), but platforms may also pass the full path, so match both.
case "$1" in
  uwsgi|/venv/bin/uwsgi)
    /venv/bin/python manage.py migrate --noinput
    ;;
esac

if [ "x$DJANGO_LOAD_INITIAL_DATA" = 'xon' ]; then
    # Only load the demo data when the database is empty. Re-running load_initial_data
    # on every boot (deploys, instance restarts) would re-insert the fixture and, for
    # media, copy duplicate files into storage each time a persistent volume is used.
    SEED_DB_HAS_DATA=$(/venv/bin/python -c "import django; django.setup(); from bakerydemo.breads.models import BreadPage; print(1 if BreadPage.objects.exists() else 0)" 2>/dev/null || true)
    if [ "x$SEED_DB_HAS_DATA" = 'x1' ]; then
        >&2 echo "Demo data already loaded - skipping load_initial_data"
    else
        /venv/bin/python manage.py load_initial_data
    fi
fi

exec "$@"

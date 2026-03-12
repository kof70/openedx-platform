#!/bin/bash
# Script pour générer les secrets nécessaires pour Coolify

echo "=== Secrets pour Coolify - openedx-native ==="
echo ""
echo "MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)"
echo "MYSQL_PASSWORD=$(openssl rand -base64 32)"
echo "MONGO_PASSWORD=$(openssl rand -base64 32)"
echo "MEILI_MASTER_KEY=$(openssl rand -base64 32)"
echo ""
echo "SECRET_KEY (Django):"
python3 -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())" 2>/dev/null || python -c "import secrets; print(secrets.token_urlsafe(50))"
echo ""
echo "=== Copie ces valeurs dans Coolify UI ==="
echo "Coolify → Projet 2026 → openedx-native → Environment Variables"

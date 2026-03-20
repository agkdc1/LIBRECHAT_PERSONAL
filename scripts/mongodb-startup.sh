#!/bin/bash
set -euo pipefail

# Idempotency: skip if already set up
if [ -f /etc/mongod.setup.done ]; then
  echo "MongoDB already configured, skipping."
  exit 0
fi

PROJECT_ID=$(curl -s "http://metadata.google.internal/computeMetadata/v1/project/project-id" \
  -H "Metadata-Flavor: Google")

# ── Install MongoDB 7 ────────────────────────────────────────────────────────

apt-get update -qq
apt-get install -y -qq gnupg curl

curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
  gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

echo "deb [signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg] http://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" \
  > /etc/apt/sources.list.d/mongodb-org-7.0.list

apt-get update -qq
apt-get install -y -qq mongodb-org

# ── Fetch secrets from Secret Manager ────────────────────────────────────────

MONGO_PASSWORD=$(gcloud secrets versions access latest \
  --secret=mongodb-password --project="$PROJECT_ID")
MONGO_PORT=$(gcloud secrets versions access latest \
  --secret=mongodb-port --project="$PROJECT_ID")
MONGO_KEYFILE=$(gcloud secrets versions access latest \
  --secret=mongodb-auth-key --project="$PROJECT_ID")

# ── Write auth keyfile ───────────────────────────────────────────────────────

echo "$MONGO_KEYFILE" > /etc/mongodb-keyfile
chmod 600 /etc/mongodb-keyfile
chown mongodb:mongodb /etc/mongodb-keyfile

# ── Phase 1: Start without auth to create admin user ─────────────────────────

cat > /etc/mongod.conf << CONF
storage:
  dbPath: /var/lib/mongodb
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.25
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: $MONGO_PORT
  bindIp: 0.0.0.0
CONF

systemctl start mongod
sleep 5

mongosh --port "$MONGO_PORT" admin --eval "
  db.createUser({
    user: 'admin',
    pwd: '$MONGO_PASSWORD',
    roles: [{role: 'root', db: 'admin'}]
  })
"

systemctl stop mongod
sleep 2

# ── Phase 2: Restart with authorization enabled ──────────────────────────────

cat > /etc/mongod.conf << CONF
storage:
  dbPath: /var/lib/mongodb
  wiredTiger:
    engineConfig:
      cacheSizeGB: 0.25
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log
net:
  port: $MONGO_PORT
  bindIp: 0.0.0.0
security:
  authorization: enabled
  keyFile: /etc/mongodb-keyfile
CONF

systemctl enable mongod
systemctl start mongod

touch /etc/mongod.setup.done
echo "MongoDB setup complete on port $MONGO_PORT"

#!/bin/bash

set -o allexport
source .env
set +o allexport

# Check argument
if [[ $# -eq 0 ]]; then
    echo "ERROR: No File Specified!"
fi

FILE="$1"
BOT_MSG_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendMessage"
BOT_BUILD_URL="https://api.telegram.org/bot${BOT_TOKEN}/sendDocument"

# Validate file
if [[ ! -f "$FILE" ]]; then
    echo "ERROR: File not found: $FILE"
fi

# Check jq
command -v jq >/dev/null || {
    echo "ERROR: jq not installed. Install via: sudo apt install jq"
}

FILESIZE=$(du -sh "$FILE" | cut -f1)

echo "📁 File: $FILE"
echo "📦 Size: $FILESIZE"
echo "📡 Trying GoFile servers..."
echo

# Notify telegram
curl -s -X POST "$BOT_MSG_URL" \
    -d chat_id="$CHAT_ID" \
    -d parse_mode="Markdown" \
    -d text="📤 *Upload Started*
📁 File: \`$FILE\`
📦 Size: $FILESIZE"

SERVERS=(store2 store3 store4 store5)
SUCCESS=0

for S in "${SERVERS[@]}"; do
    echo "➡️  Trying server: $S ..."

    RESP=$(curl -4 --http1.1 --progress-bar \
        -F "file=@${FILE}" "https://${S}.gofile.io/uploadFile")

    STATUS=$(echo "$RESP" | jq -r '.status')

    if [[ "$STATUS" == "ok" ]]; then
        LINK=$(echo "$RESP" | jq -r '.data.downloadPage')
        echo
        echo "✅ Upload Successful on ${S}"
        echo "🔗 Link: $LINK"

        # Notify telegram on success
        curl -s -X POST "$BOT_MSG_URL" \
            -d chat_id="$CHAT_ID" \
            -d parse_mode="Markdown" \
            -d text="✅ *Upload Successful*
📁 File: \`$FILE\`
📦 Size: $FILESIZE
🌐 Server: $S
🔗 Link: $LINK"

        SUCCESS=1
        break
    else
        echo "❌ Failed on $S, trying next..."
        echo
    fi
done

if [[ $SUCCESS -eq 0 ]]; then
    echo "🚫 Upload failed on all servers."

    # Notify telegram on failure
    curl -s -X POST "$BOT_MSG_URL" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode="Markdown" \
        -d text="🚫 *Upload Failed*
📁 File: \`$FILE\`
❌ All GoFile servers failed."

    exit 1
fi

echo
echo "🎉 Done!"

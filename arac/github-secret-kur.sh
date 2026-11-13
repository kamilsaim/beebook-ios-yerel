#!/usr/bin/env bash
# BeeBook iOS (yerel) — 5 imza/App Store secret'ını gizli depoya yükler. Değerler ekrana basılmaz.
# Kamil çalıştırır:  ! bash "E:/ksaim/claude programlar/aricilik/ios-yerel/arac/github-secret-kur.sh"
set -e
DEPO="kamilsaim/beebook-ios-yerel"
SERT="/c/apk/apple-anahtar/dagitim-sertifikasi"
P8="/c/apk/apple-anahtar/asc-api/AuthKey_GTQ97LCA87.p8"
printf '%s' "GTQ97LCA87" | gh secret set ASC_KEY_ID -R "$DEPO"
printf '%s' "6a682700-506a-456d-9768-f18908898acd" | gh secret set ASC_ISSUER_ID -R "$DEPO"
base64 -w0 "$P8" | gh secret set ASC_KEY_P8_BASE64 -R "$DEPO"
gh secret set DIST_CERT_P12_BASE64 -R "$DEPO" < "$SERT/GITHUB-DIST_CERT_P12_BASE64.txt"
gh secret set DIST_CERT_PASSWORD -R "$DEPO" < "$SERT/GITHUB-DIST_CERT_PASSWORD.txt"
gh secret list -R "$DEPO"
echo "TAMAM: secret'lar yüklendi."

#!/usr/bin/env bash
set -u
CURL=/usr/bin/curl
H='Content-Type: application/json'

PRODUCT=http://localhost:8500/product-service
USER=http://localhost:8700/user-service
ORDER=http://localhost:8300/order-service
PAYMENT=http://localhost:8400/payment-service

post() {
  local url="$1" body="$2"
  $CURL -s -w "\n%{http_code}" -H "$H" -X POST "$url" -d "$body"
}

extract_id() {
  python3 -c "import sys,json;d=json.loads(sys.stdin.read());print(d.get('categoryId') or d.get('productId') or d.get('userId') or d.get('cartId') or d.get('orderId') or d.get('paymentId') or '')"
}

run() {
  local label="$1" url="$2" body="$3"
  local resp
  resp=$(post "$url" "$body")
  local code="${resp##*$'\n'}"
  local json="${resp%$'\n'*}"
  local id=""
  [[ "$code" == 2* ]] && id=$(echo "$json" | extract_id)
  printf "[%s] %s -> %s id=%s\n" "$code" "$label" "$url" "$id"
  echo "$id"
}

echo "===== 4 CATEGORIES ====="
CAT_IDS=()
for i in 1 2 3 4; do
  titles=("Electronics" "Books" "Clothing" "Home")
  body=$(printf '{"categoryTitle":"%s","imageUrl":"http://img/cat%d.png"}' "${titles[$((i-1))]}" "$i")
  id=$(run "category $i" "$PRODUCT/api/categories" "$body" | tail -1)
  CAT_IDS+=("$id")
done

echo "===== 4 PRODUCTS ====="
PROD_IDS=()
names=("Laptop X1" "Novel: The Sea" "T-Shirt Blue" "Coffee Maker")
prices=("1299.99" "14.50" "19.99" "89.00")
for i in 1 2 3 4; do
  cid="${CAT_IDS[$((i-1))]}"
  body=$(printf '{"productTitle":"%s","imageUrl":"http://img/prod%d.png","sku":"SKU-%04d","priceUnit":%s,"quantity":%d,"category":{"categoryId":%s}}' \
    "${names[$((i-1))]}" "$i" "$i" "${prices[$((i-1))]}" "$((10 * i))" "$cid")
  id=$(run "product $i" "$PRODUCT/api/products" "$body" | tail -1)
  PROD_IDS+=("$id")
done

echo "===== 4 USERS ====="
USR_IDS=()
firsts=("Alice" "Bob" "Carol" "Dave")
lasts=("Smith" "Johnson" "Williams" "Brown")
for i in 1 2 3 4; do
  body=$(printf '{"firstName":"%s","lastName":"%s","imageUrl":"http://img/u%d.png","email":"%s@test.com","phone":"+1555000%04d","credential":{"username":"%s","password":"$2a$10$abcdefghijklmnopqrstuv","roleBasedAuthority":"ROLE_USER","isEnabled":true,"isAccountNonExpired":true,"isAccountNonLocked":true,"isCredentialsNonExpired":true}}' \
    "${firsts[$((i-1))]}" "${lasts[$((i-1))]}" "$i" "$(echo ${firsts[$((i-1))]} | tr A-Z a-z)" "$i" "$(echo ${firsts[$((i-1))]} | tr A-Z a-z)")
  id=$(run "user $i" "$USER/api/users" "$body" | tail -1)
  USR_IDS+=("$id")
done

echo "===== 4 CARTS ====="
CART_IDS=()
for i in 1 2 3 4; do
  uid="${USR_IDS[$((i-1))]}"
  body=$(printf '{"userId":%s}' "$uid")
  id=$(run "cart $i" "$ORDER/api/carts" "$body" | tail -1)
  CART_IDS+=("$id")
done

echo "===== 2 ORDERS ====="
ORDER_IDS=()
NOW=$(date "+%d-%m-%Y__%H:%M:%S:000000")
for i in 1 2; do
  cid="${CART_IDS[$((i-1))]}"
  body=$(printf '{"orderDate":"%s","orderDesc":"Test order %d","orderFee":%s,"cart":{"cartId":%s}}' "$NOW" "$i" "$(awk -v n=$i 'BEGIN{print 100*n + 0.50}')" "$cid")
  id=$(run "order $i" "$ORDER/api/orders" "$body" | tail -1)
  ORDER_IDS+=("$id")
done

echo "===== 2 PAYMENTS ====="
for i in 1 2; do
  oid="${ORDER_IDS[$((i-1))]}"
  status=("COMPLETED" "IN_PROGRESS")
  body=$(printf '{"isPayed":%s,"paymentStatus":"%s","order":{"orderId":%s}}' "$([ $i -eq 1 ] && echo true || echo false)" "${status[$((i-1))]}" "$oid")
  run "payment $i" "$PAYMENT/api/payments" "$body" | tail -1 > /dev/null
done

echo
echo "Done. categories=${CAT_IDS[*]} products=${PROD_IDS[*]} users=${USR_IDS[*]} carts=${CART_IDS[*]} orders=${ORDER_IDS[*]}"

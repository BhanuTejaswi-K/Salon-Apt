#!/bin/bash

PSQL=(psql -X --quiet --username=freecodecamp --dbname=salon --tuples-only --no-align --set=ON_ERROR_STOP=1)

show_services() {
  "${PSQL[@]}" --command="SELECT service_id || ') ' || name FROM services ORDER BY service_id;"
}

printf '\n~~~~~ MY SALON ~~~~~\n\n'
printf 'Welcome to My Salon, how can I help you?\n\n'

if ! SERVICES=$(show_services); then
  printf 'Could not load salon services.\n' >&2
  exit 1
fi
printf '%s\n' "$SERVICES"

while true; do
  IFS= read SERVICE_ID_SELECTED || exit 1
  if [[ "$SERVICE_ID_SELECTED" =~ ^[0-9]+$ ]]; then
    SERVICE_NAME=$("${PSQL[@]}" --command="SELECT name FROM services WHERE service_id = $SERVICE_ID_SELECTED;") || exit 1
  else
    SERVICE_NAME=
  fi

  if [[ -n "$SERVICE_NAME" ]]; then
    break
  fi

  printf '\nI could not find that service. What would you like today?\n'
  if ! SERVICES=$(show_services); then
    printf 'Could not load salon services.\n' >&2
    exit 1
  fi
  printf '%s\n' "$SERVICES"
done

printf "\nWhat's your phone number?\n"
IFS= read CUSTOMER_PHONE || exit 1

if ! CUSTOMER_ID=$(printf '%s\n' "SELECT customer_id FROM customers WHERE phone = :'customer_phone';" | "${PSQL[@]}" --set=customer_phone="$CUSTOMER_PHONE"); then
  exit 1
fi

if [[ -z "$CUSTOMER_ID" ]]; then
  printf "\nI don't have a record for that phone number, what's your name?\n"
  IFS= read CUSTOMER_NAME || exit 1
  if ! CUSTOMER_ID=$(printf '%s\n' "INSERT INTO customers (phone, name) VALUES (:'customer_phone', :'customer_name') ON CONFLICT (phone) DO UPDATE SET phone = EXCLUDED.phone RETURNING customer_id;" | "${PSQL[@]}" --set=customer_phone="$CUSTOMER_PHONE" --set=customer_name="$CUSTOMER_NAME"); then
    exit 1
  fi
else
  CUSTOMER_NAME=$(printf '%s\n' "SELECT name FROM customers WHERE customer_id = :'customer_id';" | "${PSQL[@]}" --set=customer_id="$CUSTOMER_ID") || exit 1
fi

printf '\nWhat time would you like your %s, %s?\n' "$SERVICE_NAME" "$CUSTOMER_NAME"
IFS= read SERVICE_TIME || exit 1

if ! printf '%s\n' "INSERT INTO appointments (customer_id, service_id, time) VALUES (:'customer_id', :'service_id', :'service_time');" | "${PSQL[@]}" --set=customer_id="$CUSTOMER_ID" --set=service_id="$SERVICE_ID_SELECTED" --set=service_time="$SERVICE_TIME" >/dev/null; then
  exit 1
fi

printf '\nI have put you down for a %s at %s, %s.\n' "$SERVICE_NAME" "$SERVICE_TIME" "$CUSTOMER_NAME"
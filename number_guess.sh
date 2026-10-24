#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=number_guess -X -q -t --no-align"

if ! $PSQL -c "SELECT 1" >/dev/null 2>&1; then
  createdb -U freecodecamp number_guess 2>/dev/null || exit 1
fi

$PSQL -c "CREATE TABLE IF NOT EXISTS users(user_id SERIAL PRIMARY KEY, username VARCHAR(22) UNIQUE NOT NULL, games_played INT DEFAULT 0, best_game INT); ALTER TABLE users ADD COLUMN IF NOT EXISTS games_played INT DEFAULT 0; ALTER TABLE users ADD COLUMN IF NOT EXISTS best_game INT; CREATE TABLE IF NOT EXISTS games(game_id SERIAL PRIMARY KEY, user_id INT NOT NULL REFERENCES users(user_id), guesses INT NOT NULL);" >/dev/null 2>/dev/null

echo "Enter your username:"
read username
username_sql=$(printf '%s' "$username" | sed "s/'/''/g")

user_id=$($PSQL -c "SELECT user_id FROM users WHERE username = '$username_sql';")

if [[ -z $user_id ]]; then
  user_id=$($PSQL -c "INSERT INTO users(username) VALUES ('$username_sql') RETURNING user_id;")
  echo "Welcome, $username! It looks like this is your first time here."
else
  games_played=$($PSQL -c "SELECT games_played FROM users WHERE user_id = $user_id;")
  best_game=$($PSQL -c "SELECT best_game FROM users WHERE user_id = $user_id;")
  echo "Welcome back, $username! You have played $games_played games, and your best game took $best_game guesses."
fi

secret_number=$((RANDOM % 1000 + 1))
echo "Guess the secret number between 1 and 1000:"
read guess
guess_count=1

while [[ $guess != $secret_number ]]; do
  if ! [[ $guess =~ ^[0-9]+$ ]]; then
    echo "That is not an integer, guess again:"
  elif (( guess < secret_number )); then
    echo "It's higher than that, guess again:"
  else
    echo "It's lower than that, guess again:"
  fi
  read guess
  ((guess_count++))
done

$PSQL -c "INSERT INTO games(user_id, guesses) VALUES ($user_id, $guess_count);" >/dev/null
$PSQL -c "UPDATE users SET games_played = games_played + 1, best_game = CASE WHEN best_game IS NULL OR $guess_count < best_game THEN $guess_count ELSE best_game END WHERE user_id = $user_id;" >/dev/null
echo "You guessed it in $guess_count tries. The secret number was $secret_number. Nice job!"
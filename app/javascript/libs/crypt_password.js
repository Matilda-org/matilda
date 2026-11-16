import { decrypt } from 'libs/crypter'

// The encryption password never reaches the server: it is valid when it
// decrypts the shared phrase back to its known value, and it is then kept in
// this browser only.
const STORAGE_KEY = 'credentials_password'
const PHRASE_VALUE = 'Matilda'

function isValid (phrase, password) {
  return !!password && decrypt(phrase, password) === PHRASE_VALUE
}

// Returns the stored password if it still opens the phrase, null otherwise.
export function storedCryptPassword (phrase) {
  const password = localStorage.getItem(STORAGE_KEY)
  return isValid(phrase, password) ? password : null
}

// Stores and returns the password if valid, null otherwise.
export function unlockCryptPassword (phrase, password) {
  if (!isValid(phrase, password)) return null

  localStorage.setItem(STORAGE_KEY, password)
  return password
}

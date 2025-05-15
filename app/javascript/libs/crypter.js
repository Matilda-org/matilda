import CryptoJS from 'crypto-js'

export function crypt(content, password) {
  try {
    return CryptoJS.AES.encrypt(content, password).toString()
  } catch (e) {
    console.error(e)
    return null
  }
}

export function decrypt(content, password) {
  try {
    return CryptoJS.AES.decrypt(content, password).toString(CryptoJS.enc.Utf8)
  } catch (e) {
    console.error(e)
    return null
  }
}
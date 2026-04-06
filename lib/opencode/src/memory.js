import fs from 'node:fs'
import path from 'node:path'

const BASE_PATH = path.resolve(process.cwd(), 'memory')
if (!fs.existsSync(BASE_PATH)) {
  fs.mkdirSync(BASE_PATH)
}

const memory = {} // In-memory cache for quick access

async function readMemory(taskId, key) {
  if (memory[taskId] && memory[taskId][key]) {
    return memory[taskId][key]
  }

  const filePath = `${BASE_PATH}/${taskId}.json`
  if (fs.existsSync(filePath)) {
    const data = JSON.parse(fs.readFileSync(filePath, 'utf-8'))
    memory[taskId] = data
    if (data[key]) {
      return data[key]
    }
  }

  return null
}

async function writeMemory(taskId, key, value) {
  if (!memory[taskId]) {
    memory[taskId] = {}
  }
  memory[taskId][key] = value

  const filePath = `${BASE_PATH}/${taskId}.json`
  let data = {}
  if (fs.existsSync(filePath)) {
    data = JSON.parse(fs.readFileSync(filePath, 'utf-8'))
  }
  data[key] = value
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf-8')

  return true
}

async function deleteMemory(taskId) {
  delete memory[taskId]
  const filePath = `${BASE_PATH}/${taskId}.json`
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath)
  }
  return true
}

// Optional: Implement a cleanup function to remove old memory files (older than 7 days)
async function cleanMemory() {
  const files = fs.readdirSync(BASE_PATH)
  const now = Date.now()
  const sevenDays = 7 * 24 * 60 * 60 * 1000

  files.forEach(file => {
    const filePath = `${BASE_PATH}/${file}`
    const stats = fs.statSync(filePath)
    if (now - stats.mtimeMs > sevenDays) {
      fs.unlinkSync(filePath)
    }
  })
}

export {
  readMemory,
  writeMemory,
  deleteMemory,
  cleanMemory
}
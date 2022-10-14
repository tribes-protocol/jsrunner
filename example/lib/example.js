const functions = {}

class NativeResponseCallback {
  constructor(
    resolve,
    reject,
  ) {
    this.resolve = resolve
    this.reject = reject
  }
}

const callbacks = {}


function call(json) {
  const { uuid, funcName, args } = json
  callAsync(uuid, funcName, args)
  return true
}

function getBridge() {
  const bridge = window.webkit ? window.webkit.messageHandlers.native : window.native
  return bridge
}

async function callAsync(uuid, funcName, args) {
  const bridge = getBridge()
  try {
    const result = await functions[funcName](...args)
    console.log(`result ${JSON.stringify(result)}`)
    bridge.postMessage(JSON.stringify({ type: "response", uuid, value: result }))
  } catch (e) {
    console.error(`error calling ${funcName}: ${e} `, e)
    bridge.postMessage(JSON.stringify({ type: "response", uuid, error: { message: e?.message, code: e?.code } }))
  }
}

function getRandomInt(max) {
  return Math.floor(Math.random() * max);
}

async function callNative(funcName, ...args) {
  const bridge = getBridge()
  const uuid = '' + getRandomInt(100000)
  const promise = new Promise((resolve, reject) => {
    callbacks[uuid] = new NativeResponseCallback(resolve, reject)
  })


  bridge.postMessage(JSON.stringify({ type: 'request', uuid, funcName, args }))
  return await promise
}

function respondToNative(json) {
  const { uuid, value, error } = json
  const callback = callbacks[uuid]
  if (callback) {
    if (error) {
      callback.reject(error)
    } else {
      callback.resolve(value)
    }
  }

  delete callbacks[uuid]

  return true
}

window.callJS = call
window.respondToNative = respondToNative

async function randomFunc(name, age, array) {
  console.log('randomFunc')
  return { name, age, array }
}

async function failureFunc(name) {
  console.log('failureFunc')
  throw new Error('failureFunc_called_' + name)
}

functions.randomFunc = randomFunc
functions.failureFunc = failureFunc

setTimeout(() => {
  callNative('testMethod', 30, [1, 2, 3])
    .then((result) => {
      console.log('from dart', result)
    })
    .catch((e) => {
      console.error('error', e)
    })
}, 3000)
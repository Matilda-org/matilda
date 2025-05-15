// From https://github.com/curtistimson/flashing-page-title-notification/blob/develop/src/index.js.
window.pageTitleNotification = (function () {

  var config = {
      currentTitle: null,
      interval: null
  };

  var on = function (notificationText, intervalSpeed) {
      if (!config.interval) {
          config.currentTitle = document.title;
          config.interval = window.setInterval(() => {
              document.title = (config.currentTitle === document.title)
                  ? notificationText
                  : config.currentTitle;
          }, (intervalSpeed) ? intervalSpeed : 1000);
      }
  };

  var off = function () {
      if (!config.interval) return
      window.clearInterval(config.interval);
      config.interval = null;
      document.title = config.currentTitle;
  };

  return {
      on: on,
      off: off
  };

})()

export function flashOn(text, speed = 2000) {
  pageTitleNotification.on(text, speed)

  const headLinkIcons = document.querySelectorAll('head link[rel="icon"], head link[rel="apple-touch-icon"]')
  headLinkIcons.forEach((icon) => {
    let href = icon.href.split('.')
    href[href.length - 2] = href[href.length - 2] + '-alert'
    icon.href = href.join('.')
  })
}

export function flashOff() {
  pageTitleNotification.off()

  const headLinkIcons = document.querySelectorAll('head link[rel="icon"], head link[rel="apple-touch-icon"]')
  headLinkIcons.forEach((icon) => {
    let href = icon.href.split('.')
    href[href.length - 2] = href[href.length - 2].replace('-alert', '')
    icon.href = href.join('.')
  })
}
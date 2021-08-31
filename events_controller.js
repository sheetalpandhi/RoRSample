import { Controller } from "stimulus";

export default class extends Controller {
  static values = {  url: String, refreshInterval: Number }

  connect() {
    console.log('Hello from eventsController');
    this.load()

    if (this.hasRefreshIntervalValue) {
      this.startRefreshing()
    }
  }

  disconnect() {
    this.stopRefreshing()
  }

  load() {

    const notifIcon = document.querySelector(".notifications_events")

    fetch(this.urlValue, { headers: { accept: "application/json"} })
    .then(response => response.json())
    .then(data => {
      if (notifIcon) {
        if (data.notifications_events_counter == 0) {
          notifIcon.style.visibility = "hidden"
        } else {
            notifIcon.style.visibility = "visible"
            this.element.innerHTML = data.notifications_events_counter;
        }
      }
    });
  }

  startRefreshing() {
    this.refreshTimer = setInterval(() => {
      this.load()
    }, this.refreshIntervalValue)
  }

  stopRefreshing() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }
}

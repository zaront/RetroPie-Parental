#!/usr/bin/env python3

import sys
import flask
import file
import os
import flask_basicauth
import logging
import datetime

ROOT, FILENAME = os.path.split(os.path.abspath(__file__))
app = flask.Flask(__name__)

app.config['BASIC_AUTH_USERNAME'] = 'admin'
app.config['BASIC_AUTH_PASSWORD'] = file.get_passwords()["webAdmin"]

auth = flask_basicauth.BasicAuth(app)

@app.route('/')
@auth.required
def index():
    return app.send_static_file("index.html")

@app.route("/log/<int:prevWeeks>")
def log(prevWeeks):
    return flask.jsonify(file.get_log(prevWeeks, True))

@app.route("/graph/<int:prevWeeks>")
def graph(prevWeeks):
    # load data
    logFile = file.get_log(prevWeeks)
    data = logFile["data"]

    # reformat for graph
    def groupby(data, key):
        groups = {}
        for item in data:
            group_key = key(item)
            if group_key not in groups:
                groups[group_key] = []
            groups[group_key].append(item)
        return list(groups.items())

    data = filter(lambda i: i[1] == "Ended", data)
    data = groupby(data, lambda i: i[2]) # group by name
    data.sort(key=lambda i: sum(map(lambda e: e[3], i[1]))) # sort by most played
    def graph_format(i):
        i[1].sort(key=lambda e: e[0].weekday())
        days = groupby(i[1], lambda e: e[0].weekday())
        rr = 2
        return {
            "type": "bar",
            "name": i[0],
            "x": list(map(lambda e: e[1][0][0].strftime('%a'), days)),
            "y": list(map(lambda e: sum(map(lambda t: round(t[3] / 60), e[1])), days))
        }
    data = list(map(graph_format, data))
    # add first records with all the days of the week in order
    if len(data) == 0:
        data.append({"type": "bar","name":"<no games played>", "x":[], "y":[]})
    first = data[0]
    days = first["x"]
    minutes = first["y"]
    allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    first["x"] = allDays
    first["y"] = [0,0,0,0,0,0,0]
    index = 0
    for i, day in enumerate(allDays):
        if day in days:
            first["y"][i] = minutes[index]
            index += 1
    logFile["data"] = data
    return flask.jsonify(logFile)


@app.route("/schedule")
def schedule():
    return flask.jsonify(file.get_schedule())


@app.route("/schedule", methods=["POST"])
def update_schedule():
    data = flask.request.json
    if data is not None:
        file.save_schedule(data)

        # update todays reason, if it changed
        currentDay = datetime.datetime.today().weekday().strftime("%A")
        timer = file.get_timer()
        if timer["reason"] != data[currentDay]["reason"]:
            timer["reason"] = data[currentDay]["reason"]
            file.save_timer(timer)

    return flask.jsonify(data)

@app.route("/password")
def password():
    return flask.jsonify(file.get_passwords())


@app.route("/password", methods=["POST"])
def update_password():
    data = flask.request.json
    if data is not None:
        file.save_passwords(data)
    return flask.jsonify(data)

@app.route("/timer")
def timer():
    return flask.jsonify(file.get_timer())


@app.route("/timer", methods=["POST"])
def update_timer():
    data = flask.request.json
    timer = file.get_timer()

    if data.get("remaining") is not None:
        timer["remaining"] = data.get("remaining")

    if data.get("reason") is not None:
        timer["reason"] = data.get("reason")

    if data.get("unlimited") is not None:
        timer["unlimited"] = data.get("unlimited")

    if data.get("disabled") is not None:
        timer["disabled"] = data.get("disabled")

    if data.get("password") is not None:
        timer["password"] = data.get("password")

    file.save_timer(timer)
    return flask.jsonify(timer)



if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "prod":
        log = logging.getLogger('werkzeug')
        log.setLevel(logging.ERROR)
        log.disabled = True
        app.logger.disabled = True
        app.run(host="0.0.0.0", port=8080)
    else:
        app.run(host="0.0.0.0", port=8081, debug=True)

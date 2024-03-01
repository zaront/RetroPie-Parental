
import logging
import logging.handlers
import json
import os
import datetime
import csv
import glob


ROOT, FILENAME = os.path.split(os.path.abspath(__file__))
timerFile = ROOT + "/config/timer.json"
scheduleFile = ROOT + "/config/schedule.json"
passwordsFile = ROOT + "/config/passwords.json"
logFile = ROOT + "/logs/parental.log"
dateFormat = "%Y-%m-%d"
longDateFormat = "%Y-%m-%d %H:%M:%S"

logger = None
def log(message):
    global logger
    if logger is None:
        logger = logging.getLogger("log")
        logger.setLevel(logging.INFO)
        handler = logging.handlers.TimedRotatingFileHandler(logFile, when="W0", backupCount=20) # store last 20 weeks (weeks start with Monday)
        handler.setFormatter(logging.Formatter(fmt="%(asctime)s | %(message)s", datefmt=longDateFormat))
        logger.addHandler(handler)
    logger.info(message)

def get_log(prevWeeks, raw=False):
    #find log file
    files = glob.glob(logFile + "*")
    files.sort()
    if prevWeeks > len(files)-1:
        prevWeeks = len(files)-1
    if prevWeeks < 0:
        prevWeeks = 0
    filePath = files[prevWeeks]
    hasPrevWeek = True if prevWeeks < len(files) - 1 else False
    hasNextWeek = True if prevWeeks > 0 else False

    #read raw log file
    data = None
    day = None
    if raw == True:
        with open(filePath) as file:
            data = file.read()
            index = data.find("|")
            if index > 0:
                day = datetime.datetime.strptime(data[0:index].strip(), longDateFormat) # convert to date
            else:
                day = datetime.datetime.now()
    #read parsed log file
    else:
        data = []
        with open(filePath) as file:
            reader = csv.reader(file, delimiter="|")
            for row in reader:
                for i in range(len(row)):
                    row[i] = row[i].strip()
                row[0] = datetime.datetime.strptime(row[0], longDateFormat) # convert to date
                if len(row) >= 4:
                    row[3] = int(row[3]) # convert to number
                data.append(row)
        day = data[0][0]
    
    #get the week description
    day = day.replace(hour=0, minute=0, second=0, microsecond=0)
    start = day - datetime.timedelta(days=day.weekday())
    end = start + datetime.timedelta(days=6)
    weekOf = start.strftime("%b %d") + " - " + end.strftime("%b %d %Y")

    return {"data": data, "weekOf": weekOf, "hasPrevWeek": hasPrevWeek, "hasNextWeek": hasNextWeek}

def __load(filePath, defaultFunc):
    if os.path.isfile(filePath):
        with open(filePath) as file:
            return json.load(file)
    else:
        default = defaultFunc()
        __save(filePath, default)
        return default

def __save(filePath, data):
    #insure directory
    path = os.path.abspath(os.path.dirname(filePath))
    if not os.path.exists(path):
        os.makedirs(path)

    with open(filePath, "w") as file:
        json.dump(data, file, indent=4)

def get_timer():
    def default():
        return {
            "date": (datetime.date.today()-datetime.timedelta(days=1)).strftime(dateFormat),
            "started": False,
            "currentGame": "",
            "startTime": 0,
            "remaining": 0,
            "reason": "",
            "unlimited": False,
            "disabled": False
            }
    data = __load(timerFile, default)
    __refresh_timer(data)
    return data

def save_timer(data):
    __save(timerFile, data)

def get_schedule():
    def default():
        return {
            "Monday": {"minutes":60, "reason":""},
            "Tuesday": {"minutes":60, "reason":""},
            "Wednesday": {"minutes":60, "reason":""},
            "Thursday": {"minutes":60, "reason":""},
            "Friday": {"minutes":60, "reason":""},
            "Saturday": {"minutes":60, "reason":""},
            "Sunday": {"minutes":0, "reason":"It's Sunday"}
            }
    return __load(scheduleFile, default)

def save_schedule(data):
    __save(scheduleFile, data)

def get_passwords():
    def default():
        return {
            "unlimited": ["up","down", "left", "right", "lshoulder", "rshoulder", "Y", "B", "X", "A"],
            "webAdmin": "retropie"
            }
    return __load(passwordsFile, default)

def save_passwords(data):
    __save(passwordsFile, data)

def __refresh_timer(data):
    """if its a new day, update the timer based on the schedule"""
    if datetime.date.today().strftime(dateFormat) != data["date"]:
        schedule = get_schedule()
        day = schedule[datetime.date.today().strftime("%A")]
        data["remaining"] = day["minutes"] * 60
        data["reason"] = day["reason"]
        data["date"] = datetime.date.today().strftime(dateFormat)
        data["startTime"] = 0
        __save(timerFile, data)
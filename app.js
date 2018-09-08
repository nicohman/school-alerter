var conf = require("./config.json");
var schedules = require("./schedules/"+conf.sched+".json");
var moment = require("moment");
var FeedParser = require('feedparser');
var request = require('request');
const accountSid = conf.acs;
const authToken = conf.at;
const name = conf.name;
const client = require('twilio')(accountSid, authToken);
const from = conf.from;
function check (calender) {
	var now = moment();
	var req = request(calender);
	var feedparser = new FeedParser();
	req.on('response', function (res) {
		var stream = this;
		if (res.statusCode !== 200) {
			this.emit('error', new Error('Bad status code'));
		}
		else {
			stream.pipe(feedparser);
		}
	});
	var todays = [];
	feedparser.on('readable', function () {
		var stream = this;
		var meta = this.meta;
		var item;
		while (item = stream.read()) {
			var da = item.categories[0];
			var then = moment(da, "YYYY/MM/DD (ddd)");
			if (then.isSame(now, "day")){
				todays.push(item);
			}
		}
	});
	feedparser.on("end", function(){
		checkAll(todays);
	});
}
function ssort(a, b) {
	if (a.priority > b.priority){
		return -1;
	} else if (a.priority < b.priority) {
		return 1;
	} else {
		return 0;
	}
}
function notify(day) {
	console.log("However, today is a "+day.pname);
	conf.numbers.forEach(function(n){
		console.log("Sending to "+n);
		client.messages
			.create({
				body: 'Today is a '+day.pname+". "+name+" needs to be at school by "+day.arrival,
				from: from,
				to: n
			})
			.then(message => console.log(message.sid))
			.done();
	});
}
function checkAll(todays) {
	var done = false;
	todays.forEach(function(t){
		var res = checkEvent(t);
		if (res){
			done = res;
		} else {
			console.log(t.title+" is not a schedule-affecting event!");
		}
	});
	var tnum = moment().day() - 1 ;
	var tday = schedules.days[schedules["default"][tnum]];
	console.log("Today's default is "+tday.pname);
	if (done) {
		notify(done);
	} else {
		notify(tday);
	}
}
function checkEvent (item) {
	var days = Object.keys(schedules.days).sort(ssort);
	var i = 0;
	var tday = false;
	for(var i=0; i< days.length;i++){
		var day = days[i];
		var to = schedules.days[day];
		for(var y=0; y< to.names.length;y++){
			var name = to.names[y];
			if (item.title.toLowerCase().indexOf(name.toLowerCase()) != -1) {
				tday = to;
				y = 100;
				i = 100;
			}
		}
	}
	return tday;
}
var day = moment().day;
if(day !== 0 && day !== 6){
	check(schedules.url);
} else {
	console.log("Today is a Saturday or Sunday");
}

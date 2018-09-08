var schedules = require("./schedules/cedarcrest.json");
var moment = require("moment");
var FeedParser = require('feedparser');
var request = require('request'); // for fetching the feed
function check (calender) {
	var now = moment();
	var req = request(calender);
	var feedparser = new FeedParser();

	req.on('error', function (error) {
		// handle any request errors
	});

	req.on('response', function (res) {
		var stream = this; // `this` is `req`, which is a stream

		if (res.statusCode !== 200) {
			this.emit('error', new Error('Bad status code'));
		}
		else {
			stream.pipe(feedparser);
		}
	});

	feedparser.on('error', function (error) {
		// always handle errors
	});
	var todays = [];
	feedparser.on('readable', function () {
		// This is where the action is!
		var stream = this; // `this` is `feedparser`, which is a stream
		var meta = this.meta; // **NOTE** the "meta" is always available in the context of the feedparser instance
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
			if (item.title.indexOf(name) != -1) {
				console.log("Found day!");
				tday = to;
				y = 100;
				i = 100;
			}
		}
	}
	return tday;
}
check(schedules.url);

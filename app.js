var schedules = require("./schedules/cedarcrest.json");
var moment = require("moment");
var FeedParser = require('feedparser');
var request = require('request'); // for fetching the feed
function check () {
	var now = moment();
	var req = request("https://www.trumba.com/calendars/cedarcrest-high-school.rss");
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
	console.log("h");
	feedparser.on('readable', function () {
		// This is where the action is!
		var stream = this; // `this` is `feedparser`, which is a stream
		var meta = this.meta; // **NOTE** the "meta" is always available in the context of the feedparser instance
		var item;

		while (item = stream.read()) {
			var da = item.categories[0];
			var then = moment(da, "YYYY/MM/DD (ddd)");
			if (then.isSame(now, "day")){
				console.log(item);
			}
		}
	});
}
check();

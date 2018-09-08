# school-alerter

A NodeJS program to automatically text me when I have to be at my school today. 

# Installation

You need to run `npm install` once you've cloned the repo. I recommend setting up a cron job to run `node app.js`. If you want to use different arrival times, different schedules, etc. Feel free to create your own schedule, place it in schedules, and edit app.js to use that instead. You require a `config.json` file containing the numbers that should be texted, twilio account details, and the twilio number to send from.

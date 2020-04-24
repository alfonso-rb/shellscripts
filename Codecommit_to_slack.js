/**
 * @Author: Alfonso Brown <alfonsob>
 * @Date:   2018-04-25T20:38:20-04:00
 * @Filename: Codecommit_to_slack.js
 * @Last modified by:   alfonsob
 * @Last modified time: 2018-04-25T20:50:40-04:00
 */


console.log('Loading function');

const https = require('https');
const url = require('url');
const util = require('util');

// Since it's codecommit, always use "good" for messages
const severity = "good";

// to get the slack hook url, go into slack admin and create a new "Incoming Webhook" integration
const slack_url = process.env.SLACK_WEBHOOK_URL;
const slack_req_opts = url.parse(slack_url);
slack_req_opts.method = 'POST';
slack_req_opts.headers = {'Content-Type': 'application/json'};

exports.handler = function(event, context) {
  //console.log(JSON.stringify(event, null, 2));

  (event.Records || []).forEach(function (rec) {
    if (rec.Sns) {
      var req = https.request(slack_req_opts, function (res) {
        if (res.statusCode === 200) {
          context.succeed('posted to slack');
        } else {
          context.fail('status code: ' + res.statusCode);
        }
      });

      req.on('error', function(e) {
        console.log('problem with request: ' + e.message);
        context.fail(e.message);
      });

      var postData = {
        "username": "AWS CodeCommit Event",
        "text": "*" + event.Records[0].Sns.Subject + " " + event.Records[0].Sns.Timestamp + "*"
      };

      var message = event.Records[0].Sns.Message;
      console.log('SNS Subject:', event.Records[0].Sns.Subject);
      console.log('SNS Time:', event.Records[0].Sns.Timestamp)
      console.log('SNS Message:', message);

      postData.attachments = [
        {
            "color": severity,
            "text": message
        }
      ];

      req.write(util.format("%j", postData));
      req.end();
    }
  });
};

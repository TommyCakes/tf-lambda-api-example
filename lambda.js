const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB({apiVersion: '2012-08-10'});

exports.handler = (event, context, callback) => {
    dynamoDB.putItem({
        TableName: "names",
        Item: {
            "name": {
                S: event.queryStringParameters["name"]
            }
        }
    }, function(err, data){
        if (err) {
            console.log(err, err.stack);                
            callback(null, {
                statusCode: '500',
                body: err
            });
        } else {
            callback(null, {
                statusCode: '200',
                body: 'Hello there ' + event.queryStringParameters["name"] + '!' + "you're name has been saved to the DB!"
            });
        }
    })
};


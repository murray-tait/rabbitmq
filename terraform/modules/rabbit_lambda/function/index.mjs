console.log("Loading function");

let queueName = process.env.RABBITMQ_QUEUE_NAME;
let vhost = process.env.RABBITMQ_VIRTUAL_HOST;

export const handler = async (event, context) => {
  console.log("event: ", JSON.stringify(event));
  var messages = event["rmqMessagesByQueue"][queueName + "::" + vhost];

  for (let i = 0; i < messages.length; i++) {
    var data = messages[i].data;
    var decoded = JSON.parse(atob(data));
    console.log("decoded =", decoded);
  }
  return {
    statusCode: 200,
    body: "Success!",
  };
};

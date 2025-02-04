import { Connection as RabbitConnection } from "rabbitmq-client";

import {
    GetSecretValueCommand,
    SecretsManagerClient,
} from "@aws-sdk/client-secrets-manager";

interface ConsumerContainerProps {
    secretArn: string;
}

interface RabbitConsumerProps {
    host: string;
    vhost: string;
    port: number;
    queue: string;
    username: string;
    password: string;
}

const getSecretValue = async (secretId: string) => {
    const client = new SecretsManagerClient();
    const response = await client.send(
        new GetSecretValueCommand({
            SecretId: secretId,
        })
    );
    console.log(response);
    if (response.SecretString) {
        return response.SecretString;
    }
    if (response.SecretBinary) {
        throw new Error("SecretBinary is not supported");
    }
    throw new Error("Malformed response");
};

if (!process.env.RABBIT_SECRET_ARN) {
    throw new Error(
        "Environment Variable Missing: RABBIT_SECRET_ARN is required"
    );
}

const secretString = await getSecretValue(process.env.RABBIT_SECRET_ARN);
const secret: RabbitConsumerProps = JSON.parse(secretString);

const rabbitConnection = new RabbitConnection({
    hostname: secret.host,
    vhost: secret.vhost,
    port: secret.port,
    username: secret.username,
    password: secret.password,
});

rabbitConnection.on("error", (err) => {
    console.log("RabbitMQ connection error", err);
});

rabbitConnection.on("connection", () => {
    console.log("Connection successfully (re)established");
});

const rabbitSubscription = rabbitConnection.createConsumer(
    {
        queue: secret.queue,
    },
    async (msg) => {
        console.log("received message (user-events)", msg);
    }
);

rabbitSubscription.on("error", (err) => {
    console.log("consumer error (user-events)", err);
});

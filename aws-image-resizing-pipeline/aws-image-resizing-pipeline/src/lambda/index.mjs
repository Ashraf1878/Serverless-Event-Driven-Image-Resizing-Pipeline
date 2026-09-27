import { S3Client, GetObjectCommand, PutObjectCommand } from '@aws-sdk/client-s3';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';
import sharp from 'sharp';

const s3 = new S3Client({});
const sns = new SNSClient({});

const TARGET_BUCKET = process.env.DESTINATION_BUCKET;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;
const TARGET_WIDTH = parseInt(process.env.RESIZE_WIDTH || '300', 10);

export const handler = async (event) => {
  const record = event.detail;
  const srcBucket = record.bucket.name;
  const srcKey = decodeURIComponent(record.object.key.replace(/\+/g, ' '));

  console.log(`Processing image: ${srcKey} from bucket: ${srcBucket}`);

  try {
    const getObjResponse = await s3.send(
      new GetObjectCommand({ Bucket: srcBucket, Key: srcKey })
    );
    const imageByteArray = await getObjResponse.Body.transformToByteArray();

    const resizedBuffer = await sharp(imageByteArray)
      .resize({ width: TARGET_WIDTH })
      .toFormat('jpeg', { quality: 80 })
      .toBuffer();

    const destKey = `thumbnails/${srcKey.replace(/\.[^/.]+$/, '')}_thumb.jpg`;
    await s3.send(
      new PutObjectCommand({
        Bucket: TARGET_BUCKET,
        Key: destKey,
        Body: resizedBuffer,
        ContentType: 'image/jpeg',
      })
    );

    console.log(`Successfully saved resized image to s3://${TARGET_BUCKET}/${destKey}`);

    if (SNS_TOPIC_ARN) {
      await sns.send(
        new PublishCommand({
          TopicArn: SNS_TOPIC_ARN,
          Subject: 'Image Resizing Complete',
          Message: JSON.stringify({
            status: 'SUCCESS',
            sourceFile: srcKey,
            destinationFile: destKey,
            timestamp: new Date().toISOString(),
          }),
        })
      );
    }

    return { statusCode: 200, body: 'Processing complete' };
  } catch (error) {
    console.error('Error processing image:', error);
    throw error;
  }
};

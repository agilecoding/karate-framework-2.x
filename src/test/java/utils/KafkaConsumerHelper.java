package utils;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;

/**
 * Thin wrapper around KafkaConsumer for Karate Java interop. Subscribes in the constructor so
 * tests can create the consumer BEFORE producing messages (avoids the classic race condition
 * where a message is produced before the consumer group has joined/rebalanced).
 *
 *   * def KafkaConsumerHelper = Java.type('utils.KafkaConsumerHelper')
 *   * def consumer = new KafkaConsumerHelper(bootstrapServers, uniqueGroupId, topic)
 *   * def records = consumer.poll(1000)
 */
public class KafkaConsumerHelper {

    private final KafkaConsumer<String, String> consumer;

    public KafkaConsumerHelper(String bootstrapServers, String groupId, String topic) {
        Properties props = new Properties();
        props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        props.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, true);
        this.consumer = new KafkaConsumer<>(props);
        this.consumer.subscribe(Collections.singletonList(topic));
    }

    public List<Map<String, Object>> poll(long timeoutMs) {
        List<Map<String, Object>> results = new ArrayList<>();
        ConsumerRecords<String, String> records = consumer.poll(Duration.ofMillis(timeoutMs));
        for (ConsumerRecord<String, String> r : records) {
            Map<String, Object> m = new HashMap<>();
            m.put("key", r.key());
            m.put("value", r.value());
            m.put("partition", r.partition());
            m.put("offset", r.offset());
            m.put("topic", r.topic());
            results.add(m);
        }
        return results;
    }

    public void close() {
        consumer.close();
    }
}

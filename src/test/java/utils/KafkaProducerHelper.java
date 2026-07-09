package utils;

import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;

import java.util.HashMap;
import java.util.Map;
import java.util.Properties;

/**
 * Thin wrapper around KafkaProducer so Karate features can send messages via Java interop:
 *   * def KafkaProducerHelper = Java.type('utils.KafkaProducerHelper')
 *   * def producer = new KafkaProducerHelper(bootstrapServers)
 *   * producer.send(topic, key, jsonString)
 * Returns a plain Map (not the raw RecordMetadata object) so Karate's JS layer can match on it.
 */
public class KafkaProducerHelper {

    private final KafkaProducer<String, String> producer;

    public KafkaProducerHelper(String bootstrapServers) {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.ENABLE_IDEMPOTENCE_CONFIG, true);
        props.put(ProducerConfig.RETRIES_CONFIG, 3);
        this.producer = new KafkaProducer<>(props);
    }

    public Map<String, Object> send(String topic, String key, String value) {
        try {
            ProducerRecord<String, String> record = new ProducerRecord<>(topic, key, value);
            RecordMetadata metadata = producer.send(record).get();
            Map<String, Object> result = new HashMap<>();
            result.put("topic", metadata.topic());
            result.put("partition", metadata.partition());
            result.put("offset", metadata.offset());
            return result;
        } catch (Exception e) {
            throw new RuntimeException("Kafka send failed: " + e.getMessage(), e);
        }
    }

    public void close() {
        producer.flush();
        producer.close();
    }
}

Với yêu cầu cơ bản là encode, decode dạng short link. Có 2 hướng làm theo *Stateful* và *Stateless*.

Với stateless có thể hash url gốc bằng 1 công thức chuyển đổi cố định, có quy tắc để tạo ra short_code, khi decode thì đảo ngược lại công thức đó.
Tuy nhiên vấn đề bảo mật khó và short_code thường sẽ dài vì có thể chứa cả data và signature. Không revoke được từng short_link. Và đặc biệt không được lưu trữ lại nên khó mở rộng chức năng sau này.

Xét về tính mở rộng, quản lý short_code về sau thì sẽ implement theo hướng stateful (Lưu trữ lại short_code qua database) sẽ là lựa chọn hợp lý hơn để triển khai demo.

# Rails ShortLink API Service
A simple, scalable URL shortening service built with Ruby on Rails API, Redis cache, distributed lock, and rate limiting.
## Features

- Encode long URLs to short codes
- Decode short codes to original URLs
- Redis caching for fast decoding
- Rate limit per IP, Negative Cache with Redis for decode spam protection
- Distributed lock to prevent short code collision
- URL normalization & validation
- Centralized shortlink log per environment

**DEMO API service cho phép tạo short link và decode short link sang original URL với cơ chế:**

## [http://139.180.130.237/](http://139.180.130.237/)

*  Genrate các mã short_code và lưu lại ở database.
*  Có cơ chế retry khi tạo mã short_code đề phòng trường hợp trùng mã (Hiếm gặp, nhưng vẫn có khả năng xảy ra).
*  Có cơ chế cache lại origin_url để tránh tạo mới short_code cho url trùng.
*  Thêm cache để giảm tải query, connection đến database (cả positive & negative caching)
*  Rate limit theo IP hạn chế ddos, ngốn tài nguyên.
*  Tạo Redis với nhiều Cluster. (Khi deploy production). Tách các Cluster lưu trữ các cache khác nhau. Đễ dễ dàng scale sau này
*  Đánh index unique short_code phục vụ search và validation chặt chẽ hơn tầng database.
*  Distributed Lock với redis lock giảm thiểu nhiều request chạy song song khi encode cùng lúc, dẫn tới có thể race condition, data inconsistency khi Puma chạy nhiều thread và sau này auto scale backend do nhiều instance được tạo ra kéo theo nhiều request có thể chạy đồng thời.
*  Cũng như giảm thiếu được phải raise unique ở tầng database.

## 📖 API Endpoints
### 📌 `POST /api/v1/encode`
Tạo short link từ 1 original URL.

#### ✅ Request

**POST** `/api/v1/encode`

```json
{
  "url": "https://example.com/page"
}
```
#### 📖 Response
```json
{
  "short_code": "XyZaBc",
  "short_url": "https://example.com/XyZaBc56"
}
```
#### cURL Example:

```curl
curl -X POST http://139.180.130.237/api/v1/encode \
  -H "Content-Type: application/json" \
  -d '{"url":"https://google.com"}'
  ```


* URL phải là http hoặc https
* Rate limit: 50 requests/1 phút/IP

### 📌 `GET /api/v1/decode/:short_code`
Decode short link sang original URL.

#### ✅ Request
**GET** `/api/v1/decode/XyZaBc56`

#### 📖 Response

```json
{
  "original_url": "https://example.com/page"
}
```
**cURL:**

```curl
curl http://139.180.130.237/api/v1/decode/AbCdEf
```

* Rate limit: 50 requests/1 phút/IP

## 📚 Các Service chính

* `EncodeService` : Sinh short_code, lưu DB, set cache
* `DecodeService` : Decode short_code, check cache, set cache
* `CacheService` : Thao tác với Redis lưu cache short_code, original_url
* `RateLimitService` : Kiểm tra rate limit theo IP/action hạn chế Brute-force
* `UrlValidator` : Validate URL scheme, host cho original_url đầu vào
* `ShortLinkLogger` : Ghi log vào shortlink.log theo môi trường
* `DistributedLock`: Xử lý Distrubute lock tạo mã short_code không trùng khi chạy trên nhiều thread hoặc instance được scale. Hạn chế tối đa connection vào database.

## Logging
Log `encode/decode/rate limit` request vào `log/shortlink.log`
Tách log theo từng environment: `development, production, staging`

## ⚠️ Các Vấn Đề Collision Trong ShortLink API

Việc collision có thể gặp ở cả short_code và original_url. Khi tạo dữ liệu cũng như khi scale ứng dụng sau này.

* Trường hợp collision ở short_code.

Mọi trường hợp dù là "random" cũng không thể bảo đảm được rằng dữ liệu short_code luôn là duy nhất. 2 request khác nhau tạo ra **cùng một short_code** cho 2 URL khác nhau. Hoặc cùng 1 request gửi đồng thời tạo ra short_code trùng trước khi DB commit.
Khi dữ liệu đủ lớn, việc generate với base62 có thể tạo ra mã trùng. Ví dụ với short_code 8 ký tự được tạo bởi base62 thì có thể tạo được ra 62^8 mã short_code.
Hiện tại giải pháp để giảm thiểu đã áp dụng đó là: Sử dụng DistributeLock để lock lại logic tạo và lưu mã short_code kết hợp tạo ràng buộc unique tầng database. Nếu xảy ra việc trùng sẽ retry lại 5 lần để tạo mã short code và lưu lại trong database cho đến khi tạo được mã không trùng.
Ngoài ra khi dữ liệu đủ lớn, có thể thay đổi hàm generate_short_code để có thể chứa nhiều dữ liệu hơn. Cũng như để làm giảm dữ liệu trùng. Cần có thêm cơ chế monitoring để thông báo trước khi điều này diễn ra. Vì các mã short_code cũ đã được lưu trữ nên sẽ không ảnh hưởng gì. Tương ứng với short_code tăng thêm 1 ký tự sẽ tăng được 62 lần mã short_code.

* Trường hợp collision ở original_url

Việc người dùng cần short link các original_url giống nhau là trường hợp có thể dễ gặp. Cần có cơ chế quản lý để có thể hạn chế việc lưu trữ dữ liệu lặp không cần thiết.
Ví dụ nếu đã có người dùng short code cho link là http://google.com và được tạo với short_code là ABCD thì khi người dùng khác short link với original_url là http://google.com tiếp tục thì nên trả về short code là ABCD luôn mà không cần lưu trữ vào database và tạo short_code mới vì điều này làm tốn thêm tài nguyên và số lượng mã short_code được sinh ra.
Để giải quyết vấn đề này được triệt để hơn thì cần xử lý Normalize URL trước khi tìm kiếm, so sánh và lưu trữ thống nhất về cấu trúc original_url những vẫn bảo đảm được đầu ra. Ví dụ http://google.com:80 thì giống với http://google.com.Vì original_url là dạng text, có thể dài và khó kiểm soát về giá trị nên hạn chế việc xử lý query vào database vì trường này không đánh index sẽ làm chậm hoặc nghẽn quá trình encode.

* Ngoài ra vấn đề Collision cũng có thể xảy ra ở Redis cache khi 2 request set cache cùng lúc cho 1 short_code, hoặc delete + set đồng thời dẫn tới dữ liệu cache overwrite hoặc không đồng nhất. **Giải pháp** là dùng lock khi cần set cache quan trọng, TTL cache ngắn với decode, Log các bất thường cache overwrite để audit.


Khi scale Backend chạy ở nhiều instance, việc sử dụng Distribute Lock qua redis cũng đã giảm tối đa khả năng bị trùng lặp short_code trên toàn hệ thống. Kết hợp với index unique ở tầng database gần như có thể giảm thiểu ở mức tối đa vấn đề này. Tuy nhiên có giải pháp có thể triển khai theo phương án khác là có service riêng để chạy Job tạo ra các mã short_code trừ trước. Khi đó khi ecndoe thì pick lần lượt các mã short_code để sử dụng và đánh dấu nó.

## 🔒 Security problem

### 1. Spam/DDOS API
Attacker spam decode/encode các short_code random liên tục gây overload backend giảm hiệu năng API, database, tràn redis, xảy ra trường hợp race condition với short_code.

**Giải pháp giảm thiểu**

Hiện tại code đã implement trường hợp này, chỉ có phép request giới hạn nhất định theo IP (Rate limiting). Phần nào sẽ hạn chế được việc spam,ddos encode/decode làm tốn tài nguyên và không gian lưu trữ. Ngoài ra nên áp dụng các layer khác như firewall để giảm thiếu được tối đa hoặc 1 số bên thứ 3 như cloudfare.
Với hệ thống như short_link cần có cơ chế logging, monitoring đầy đủ để theo dõi các IP truy cập có giấu hiệu bất thường để từ đó ngăn chặn kịp thời.

### 2. Brute-force
Vì short_code link được tạo dựa trên 8 ký tự mã base62 nên có thể bị brute-force.

**Giải pháp giảm thiểu**

Tương tự như vấn đề spam API thì ngoài cách đã áp dụng giống vậy để ngăn chặn request liên tục vào hệ thống thì việc tăng số lượng ký tự mã short_code lên là cần thiết, sẽ giảm được tối đa thời gian có thể trúng được mã short_code tồn tại. Ngoài ra cần tránh cách thuật toán dễ đoán, dễ giải mã khi sinh short_code

### 3. Tạo các short code nhằm mục đích Redirect Vulnerabilities, che giấu original_url độc hại.

**Giải pháp giảm thiểu**

Có thể thêm các middleware để validate trước các original_url. Nếu phát hiện url nghi ngờ thì chặn việc tạo short_code hoặc vẫn cho phép nhưng sẽ cảnh báo phía người dùng khi redirect. Hoặc có cơ chế preview trước khi redirect cho người dùng. Nếu cần render trên giao diện thì phải escape trước.
Tích hợp Google Safe Browsing API để kiểm tra link trước khi tạo.

### 4. Bị hack database dẫn tới lộ các original_url.

**Giải pháp giảm thiểu**


Nếu dữ liệu original_url ở dạng private, có thể mã hoá chúng trước khi lưu vào database. Dù có lấy được database thì cũng cần phải có thể secret để giải mã được original_url.(Nhưng bù lại phải đánh đổi tốc độ vì khi decode cũng cần để lấy đc url gốc).
Ngoài ra nên có cơ chế private database, không public ra internet (Nếu deploy AWS thì setting cho nằm trong private subnet. Cấu hình Security Group Inbound chỉ cho phép IP của server BE)

## 📈 Scalability

Do lưu trữ short_code vào database nên việc mở rộng, quản lý về phần chức năng rất linh động. Có thể thu hồi short_code cũ, tạo short_code mới có độ dài tăng thêm mà không ảnh hưởng tới short_code cũ

Có thể xây dựng theo kiến trúc microservice để có thể dễ dàng scale cả chiều dọc và chiều ngang khi có lượng truy cập đột biến, nhu cầu sử dụng tăng cao. Scale đúng các service cần thiếu giúp tận dụng được tối đa nguồn tài nguyên

Về phần kỹ thuật và kiến trúc khi scaling, có thể áp dụng nhiều cách sau.

### Redis Distributed Cache & Lock (Đã áp dụng)
- Sử dụng nhiều Redis cluster để đảm bảo tính sẵn sàng cao.
- Distributed Lock với `SET NX PX` để tránh race khi tạo short_code. (Có thể sử dụng các gem thứ 3 như redlock để hỗ trợ Distributed cache khi scale hiệu quả hơn)

### Rate Limiting Per IP  (Đã áp dụng)
- Redis key per IP, reset TTL mỗi phút.
- Hạn chế tối đa brute force và spam short_code lạ.

### Cache & Negative Cache (Đã áp dụng)
- Cache original_url theo short_code
- Cache giá trị `nil` cho short_code không tồn tại trong thời gian ngắn
- Giảm truy vấn DB theo short_code

### Bloom Filter
- Dùng Bloom Filter lưu short_code đã tồn tại.
- Giảm truy vấn DB cho request decode lạ.
- Load Bloom Filter từ DB khi app khởi động hoặc cập nhật realtime.

### Database Sharding
- Phân tách bảng `short_urls` hoặc database theo prefix short_code hoặc theo ngày/tháng tạo. Điều hướng request vào đúng table/ database cần
- Scale về database, thêm replicas

### CDN Cache Cho Decode
- Frontend hoặc API Gateway caching short_url, original_url với TTL phù hợp. Khi client truy cập lại thì redirect luôn mà không cần request lên server để decode lại.
- Giảm tải backend khi request decode liên tục.

### Load Balancing/ Auto Scaling App Instance, Redis clustor, Database replicas
- Dùng Kubernetes hoặc AWS ECS, EKS để scale horizontal app instance khi traffic tăng.
- Redis cluster hoặc cloud Redis (AWS ElastiCache) để tăng số lượng Cluster tăng hiệu năng tầng cache.

### Pre-generate short_code data
- Tạo dữ liệu short_code từ trước bằng cách tạo Service chạy backgroud Job. Khi encode thì pick ra sử dụng và đánh dấu lại.

## 📊 Monitoring & Alert
- Cần có cơ chế đầy đủ để giám sát khi resrouce tăng cao
- Alert khi có các IP rơi vào Rate limmit.
- Alert khi Redis gần đầy hoặc request vượt ngưỡng.
- Alert khi số lượng short_code sắp đạt giới hạn

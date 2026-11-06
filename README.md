# discourse-post-geoip

记录每次发帖时的用户 IP，并在帖子、用户卡片和用户主页显示**部分 IP**与**IP 归属地**。插件默认关闭，需在站点设置中开启；部分 IP 与归属地可在站点设置中分别开关。

## 功能

- 发帖时把请求 IP 写入独立数据表（Discourse 本身已不再保存帖子 IP），同时记录该帖在话题中的楼层（`post_number`）。
- 帖子用户名下方显示掩码后的 IP，例如 `114.114.*.*`（IPv4）或 `2001:db8:1234:5678::`（IPv6）。
- 帖子用户名下方显示 IP 归属地，默认到省（例如 `中国 浙江`），可配置到市（例如 `中国 浙江 杭州`），数据来自 Discourse 自带的 MaxMind GeoLite2-City 数据库。
- 归属地在发帖时查询一次，并把国家、省、市写入数据库；之后显示时直接读库，不再重复查询。
- 可配置归属地显示范围：国家、省、市。
- 站点设置可分别关闭部分 IP、归属地的显示；可调整掩码保留的段数；私信默认也记录并显示。
- 可配置多个请求头（如 CDN 写入的 `CF-Connecting-IP`），把它们的值一并存入记录表的 `request_headers` 字段。
- 同时记录发帖请求的 User-Agent 与 Referer。
- 点击用户头像打开的用户卡片中，显示用户表 `users.ip_address` 对应 IP 的部分 IP 与归属地。
- 用户主页（`/u/<username>` 及其 summary 等标签页）同样显示部分 IP 与归属地。
- 删除帖子时默认保留 IP 记录；可在设置中改为同步删除。

## 安装

把本仓库放到 Discourse 的 `plugins/discourse-post-geoip` 目录，然后执行迁移并重启：

```bash
cd /var/www/discourse
su discourse -c 'RAILS_ENV=production bundle exec rake db:migrate'
```

Docker Compose 部署可在 `docker-compose.yml` 的 `web` 服务中挂载本仓库：

```yaml
volumes:
  - /path/to/discourse-post-geoip:/var/www/discourse/plugins/discourse-post-geoip
```

官方 `discourse/discourse` 镜像启动时默认跳过插件 JS 构建（`SKIP_EMBER_CLI_COMPILE=1`），因此需要在启动前编译一次插件前端资源：

```bash
cd /var/www/discourse
su discourse -c 'RAILS_ENV=production LOAD_PLUGINS=1 bundle exec rake assets:precompile:build_plugins'
```

之后重新创建容器，启动脚本会自动执行 `assets:precompile` 编译插件前端资源。

## 站点设置

| 设置 | 默认值 | 说明 |
| --- | --- | --- |
| `discourse_post_geoip_enabled` | 关 | 插件总开关；默认关闭，开启后才记录和显示 |
| `discourse_post_geoip_show_ip` | 开 | 显示部分 IP |
| `discourse_post_geoip_show_location` | 开 | 显示 IP 归属地 |
| `discourse_post_geoip_location_granularity` | `country\|region` | 归属地显示范围，可多选：`country`、`region`、`city`；默认国家+省 |
| `discourse_post_geoip_ipv4_visible_octets` | 2 | IPv4 保留显示的段数（1-3） |
| `discourse_post_geoip_ipv6_visible_groups` | 4 | IPv6 保留显示的组数（1-7） |
| `discourse_post_geoip_request_headers` | 空 | 记录这些请求头的值，列表形式，输入后回车添加，可添加多个 |
| `discourse_post_geoip_show_in_private_messages` | 开 | 私信中也记录并显示 |
| `discourse_post_geoip_delete_on_post_destroy` | 关 | 删除帖子时同步删除 IP 记录 |

设置位置：管理后台 → 设置 → 插件 → `discourse-post-geoip`。

## 记录请求头

`discourse_post_geoip_request_headers` 是列表设置：在输入框里填请求头名称，按回车（或点 `+`）即可添加，可以添加多个，例如：

```
CF-Connecting-IP | X-Real-IP | X-Forwarded-For
```

发帖时插件会把其中**实际存在**的请求头及其值写入 `discourse_post_geoip_records.request_headers`：

```json
{"CF-Connecting-IP": ["203.0.113.5"], "X-Real-IP": ["203.0.113.5"]}
```

规则：

- 请求头名大小写不敏感，Rack 形式（`HTTP_CF_CONNECTING_IP`）同样匹配；
- 每个命中的请求头都以**数组**形式保存，单值也是长度为 1 的数组；同一请求头出现多次（Rack 在某些服务器上以数组给出）会展开后完整保留，不会丢值；
- 只记录配置里列出、且请求中确实存在的请求头，缺失的不会写入，也不会写成空串；
- 列表里不符合请求头命名的项（含空格等）会被忽略；
- 值仅保存在服务端数据库，不会出现在帖子、用户卡片等任何接口返回里。

> **安全提醒**：不要添加 `Authorization`、`Cookie`、`X-CSRF-Token` 等敏感请求头——它们的值会以明文写入数据库。请求头由客户端可控，若用于判断用户身份或 IP，请确认它由 CDN / 反向代理强制覆盖。

查询示例：

```sql
SELECT post_id, topic_id, post_number, host(ip_address) AS ip, request_headers
FROM discourse_post_geoip_records
WHERE post_id = 123;

-- 取某个请求头的第一个值
SELECT request_headers -> 'CF-Connecting-IP' ->> 0 AS first_value
FROM discourse_post_geoip_records
WHERE post_id = 123;
```

## 数据表

表名：`discourse_post_geoip_records`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `id` | integer | 主键 |
| `topic_id` | integer | 话题 ID（非空） |
| `post_id` | integer | 帖子 ID（非空，唯一索引） |
| `post_number` | integer | 话题楼层；1 即话题本身（1 楼），2 为第一个回复，以此类推 |
| `user_id` | integer | 发帖用户 ID |
| `ip_address` | inet | 发帖时的完整 IP |
| `country` | string | 国家（发帖时查询并缓存） |
| `region` | string | 省/州（发帖时查询并缓存） |
| `city` | string | 城市（发帖时查询并缓存） |
| `request_headers` | jsonb | 发帖请求中配置的请求头值，每个头一个数组，如 `{"CF-Connecting-IP": ["203.0.113.5"]}`；未配置或未命中为 `NULL` |
| `user_agent` | text | 发帖请求的 User-Agent |
| `referer` | text | 发帖请求的 Referer（取 `HTTP_REFERER`，Discourse 内部参数名为 `referrer`） |
| `geolocated_ip` | inet | 已查询过归属地的 IP |
| `created_at` / `updated_at` | timestamp | 时间戳 |

`geolocated_ip` 与 `ip_address` 不一致时（例如手动修改了 `ip_address`），下次显示会自动重新查询归属地并写回缓存：

```sql
-- 把某个帖子的 IP 改成一个公网 IP
UPDATE discourse_post_geoip_records
SET ip_address = '223.5.5.5'
WHERE post_id = 123;
```

刷新帖子页面即可看到新的部分 IP 与归属地。注意：插件只记录安装之后新发布的帖子，已有帖子没有记录。

`post_number` 由发帖时写入。升级到带该列的版本时，迁移会按 `post_id` 从 `posts` 表回填历史记录；只有帖子被物理删除、`posts` 中已无对应行的记录会保持 `NULL`。

常用查询：

```sql
-- 话题 123 各楼层的 IP 与归属地
SELECT post_number, host(ip_address) AS ip, country, region, city
FROM discourse_post_geoip_records
WHERE topic_id = 123
ORDER BY post_number;

-- 话题创建者（1 楼）的 IP
SELECT host(ip_address) AS ip, country, region, city
FROM discourse_post_geoip_records
WHERE topic_id = 123 AND post_number = 1;

-- 某用户创建的话题（1 楼）及其 IP
SELECT topic_id, host(ip_address) AS ip, created_at
FROM discourse_post_geoip_records
WHERE user_id = 42 AND post_number = 1
ORDER BY created_at DESC;
```

`post_number` 不设唯一索引：Discourse 删除帖子后会复用楼层号，删除帖子又默认保留 IP 记录，两种情况会同时出现。

## IP 归属地

归属地使用 Discourse 的 `DiscourseIpInfo`（MaxMind GeoLite2-City，路径为 `vendor/data/GeoLite2-City.mmdb`），按站点默认语言返回地名，例如 `zh_CN` 下为中文。

- 发帖时查询一次，国家、省、市写入 `discourse_post_geoip_records`，之后直接读库。
- 数据库不存在时只显示部分 IP；IP 为内网地址时归属地显示为「内网」。
- 归属地精度取决于 MaxMind 数据库，中国城市可能存在只到省份或国家的情况。

## 隐私说明

- 客户端永远拿不到完整 IP，只能拿到掩码后的部分 IP。
- 完整 IP 只保存在服务端数据库中，默认仅管理员可通过数据库查看。
- 私信帖子默认也记录 IP；如不希望记录，请关闭 `discourse_post_geoip_show_in_private_messages`。
- 删除帖子默认保留 IP 记录；如需同步删除，请打开 `discourse_post_geoip_delete_on_post_destroy`。
- 用户卡片与用户主页使用 `users.ip_address`（Discourse 记录的用户 IP），同样只输出掩码和归属地，并受上述开关控制。
- `request_headers`、`user_agent`、`referer` 都可能包含敏感信息，且由客户端提供、可被伪造或为空；这些字段仅保存在服务端数据库，不会下发给客户端。

## 开发

纯 Ruby 掩码逻辑的单元测试：

```bash
bundle exec rspec plugins/discourse-post-geoip/spec/lib/discourse_post_geoip/ip_mask_spec.rb
```

import Foundation

/// Typed API surface, mapped to eapi and web API endpoints.
enum MusicAPI {
    private static var client: MusicClient { .shared }

    private static func eapi<T: Decodable>(
        _ type: T.Type, _ path: String, _ payload: [String: Any] = [:],
        requiringAuthentication binding: String? = nil
    ) async throws -> T {
        let data = try await client.eapi(path, payload, requiringAuthentication: binding)
        return try client.decoded(T.self, from: data)
    }

    struct CodeOnly: Decodable {
        let code: Int
    }

    // MARK: - Auth

    struct QRKeyResponse: Decodable {
        let code: Int
        let unikey: String
    }

    static func qrKey() async throws -> String {
        try await eapi(QRKeyResponse.self, "/login/qrcode/unikey", ["type": 3]).unikey
    }

    static func qrLoginURL(unikey: String) -> String? {
        Upstream.webURL("/login?codekey=\(unikey)")?.absoluteString
    }

    struct QRCheckResponse: Decodable {
        let code: Int
        let message: String?
        let nickname: String?
        let avatarUrl: String?
    }

    /// Codes: 800 expired · 801 waiting · 802 scanned · 803 success.
    /// On 803 the auth cookies arrive via Set-Cookie and are absorbed by the client.
    static func qrCheck(unikey: String) async throws -> QRCheckResponse {
        let data = try await client.eapi("/login/qrcode/client/login", ["key": unikey, "type": 3])
        return try JSONDecoder().decode(QRCheckResponse.self, from: data)
    }

    /// Sends an SMS verification code for phone-number login
    /// (upstream: `/api/sms/captcha/sent`). Through the web API, with the
    /// login it is for.
    static func sendSMSCode(phone: String, countryCode: String = "86") async throws {
        let data = try await client.api("/sms/captcha/sent",
                                        ["ctcode": countryCode, "cellphone": phone,
                                         "secrete": "music_middleuser_pclogin"])
        _ = try client.decoded(CodeOnly.self, from: data)
    }

    /// Phone-number login with an SMS code (upstream: `/api/w/login/cellphone`).
    /// Auth cookies arrive via Set-Cookie. Through the web API: through the
    /// eapi, the service refuses it with -460 before it checks the code.
    static func loginCellphone(phone: String, captcha: String, countryCode: String = "86") async throws {
        let data = try await client.api("/w/login/cellphone",
                                        ["type": "1", "https": "true",
                                         "phone": phone, "countrycode": countryCode,
                                         "captcha": captcha, "remember": "true"])
        _ = try client.decoded(CodeOnly.self, from: data)
        guard client.isLoggedIn else {
            throw MusicAPIError.business(code: -1, message: String(localized: "登录失败，请重试"))
        }
    }

    /// An isolated client keeps a late logout response away from a newer login.
    static func logout(
        detachedCookies: [String: String],
        using client: MusicClient = MusicClient(configuration: .ephemeral, persistsCookies: false)
    ) async throws {
        client.setCookies(detachedCookies)
        let data = try await client.eapi("/logout", absorbResponseCookies: false)
        _ = try client.decoded(CodeOnly.self, from: data)
    }

    static func refreshLogin() async {
        _ = try? await client.eapi("/login/token/refresh")
    }

    enum CookieLoginError: LocalizedError {
        case invalidHeader
        case validationFailed

        var errorDescription: String? {
            switch self {
            case .invalidHeader: return String(localized: "请输入有效的 Cookie，包含非空的 MUSIC_U，可选 __csrf")
            case .validationFailed: return String(localized: "Cookie 登录验证失败，请检查 Cookie 或稍后重试")
            }
        }
    }

    struct VerifiedLogin {
        let profile: UserProfile
        let cookies: [String: String]
    }

    /// Browser Cookie headers use single semicolons, unlike QR response cookies.
    /// Candidate credentials stay in an isolated jar until the account is verified.
    static func loginWithCookie(
        _ header: String,
        using candidate: MusicClient = MusicClient(configuration: .ephemeral, persistsCookies: false)
    ) async throws -> VerifiedLogin {
        var authentication: [String: String] = [:]
        for part in header.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let name = pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name == "MUSIC_U" || name == "__csrf" else { continue }
            guard pair.count == 2, authentication[name] == nil else { throw CookieLoginError.invalidHeader }
            let value = pair[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, value.utf8.allSatisfy({
                $0 >= 0x21 && $0 <= 0x7e && $0 != 0x22 && $0 != 0x2c && $0 != 0x5c
            }) else { throw CookieLoginError.invalidHeader }
            authentication[name] = value
        }
        guard authentication["MUSIC_U"] != nil else { throw CookieLoginError.invalidHeader }
        try Task.checkCancellation()
        do {
            try candidate.replaceAuthentication(with: authentication)
            guard let profile = try await userAccount(using: candidate), profile.userId > 0 else {
                throw CookieLoginError.validationFailed
            }
            try Task.checkCancellation()
            return VerifiedLogin(profile: profile, cookies: candidate.authenticationCookies())
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Server and transport errors may contain credential material.
            throw CookieLoginError.validationFailed
        }
    }

    struct AccountResponse: Decodable {
        let code: Int
        let profile: UserProfile?
    }

    static func userAccount(using client: MusicClient = .shared) async throws -> UserProfile? {
        let data = try await client.eapi("/nuser/account/get")
        return try client.decoded(AccountResponse.self, from: data).profile
    }

    // MARK: - User library

    struct UserPlaylistsResponse: Decodable {
        let playlist: [PlaylistSummary]
        let more: Bool?
    }

    static func userPlaylists(uid: Int, limit: Int = 2000, offset: Int = 0) async throws -> [PlaylistSummary] {
        try await eapi(UserPlaylistsResponse.self, "/user/playlist",
                       ["uid": uid, "limit": limit, "offset": offset, "includeVideo": true]).playlist
    }

    struct LikelistResponse: Decodable {
        let ids: [Int]
    }

    static func likedTrackIDs(uid: Int) async throws -> [Int] {
        try await eapi(LikelistResponse.self, "/song/like/get", ["uid": uid]).ids
    }

    /// Through the eapi as the desktop client likes a
    /// song: the web API answers "当前环境异常，已取消喜欢" to a client its
    /// risk control does not recognize, and the heart goes back.
    static func likeTrack(id: Int, like: Bool) async throws {
        _ = try await eapi(CodeOnly.self, "/radio/like",
                           ["alg": "itembased", "trackId": String(id), "like": like ? "true" : "false", "time": "3"])
    }

    struct SublistResponse<Item: Decodable>: Decodable {
        let data: [Item]
        let count: Int?
        let hasMore: Bool?
    }

    static func likedAlbums(limit: Int = 500, offset: Int = 0) async throws -> [AlbumSummary] {
        try await eapi(SublistResponse<AlbumSummary>.self, "/album/sublist",
                       ["limit": limit, "offset": offset, "total": true]).data
    }

    static func likedArtists(limit: Int = 500, offset: Int = 0) async throws -> [ArtistSummary] {
        try await eapi(SublistResponse<ArtistSummary>.self, "/artist/sublist",
                       ["limit": limit, "offset": offset, "total": true]).data
    }

    struct PlayRecordResponse: Decodable {
        let weekData: [PlayRecordItem]?
        let allData: [PlayRecordItem]?
    }

    static func playRecords(uid: Int, week: Bool) async throws -> [PlayRecordItem] {
        let resp = try await eapi(PlayRecordResponse.self, "/v1/play/record",
                                  ["uid": uid, "type": week ? 1 : 0])
        return (week ? resp.weekData : resp.allData) ?? []
    }

    struct RecentSongsResponse: Decodable {
        struct Body: Decodable {
            let list: [RecentPlay]

            private enum CodingKeys: String, CodingKey {
                case list
            }

            /// Skips an entry that is not a song rather than losing the list.
            private struct Entry: Decodable {
                let play: RecentPlay?
                init(from decoder: Decoder) throws { play = try? RecentPlay(from: decoder) }
            }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                list = ((try? c.decode([Entry].self, forKey: .list)) ?? []).compactMap(\.play)
            }
        }

        let data: Body?
    }

    /// The official 最近播放 list: songs in the order they were last played,
    /// on any device of the account. `/v1/play/record` (`playRecords`) is the
    /// listening ranking instead, ordered by play count (#198).
    static func recentSongs(limit: Int = 300, using client: MusicClient = .shared) async throws -> [RecentPlay] {
        let data = try await client.eapi("/play-record/song/list", ["limit": limit])
        let resp = try client.decoded(RecentSongsResponse.self, from: data)
        var seen: Set<Int> = []
        return (resp.data?.list ?? []).filter { $0.song.id > 0 && seen.insert($0.song.id).inserted }
    }

    struct CloudResponse: Decodable {
        let data: [CloudSongItem]?
        let hasMore: Bool?
        /// Bytes; served as a number or a numeric string depending on account age.
        let size: Int64?
        let maxSize: Int64?

        private enum CodingKeys: String, CodingKey {
            case data, hasMore, size, maxSize
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            data = try? c.decode([CloudSongItem].self, forKey: .data)
            hasMore = try? c.decode(Bool.self, forKey: .hasMore)
            size = (try? c.decode(Int64.self, forKey: .size))
                ?? (try? c.decode(String.self, forKey: .size)).flatMap(Int64.init)
            maxSize = (try? c.decode(Int64.self, forKey: .maxSize))
                ?? (try? c.decode(String.self, forKey: .maxSize)).flatMap(Int64.init)
        }
    }

    static func cloudSongs(limit: Int = 1000, offset: Int = 0) async throws -> CloudResponse {
        try await eapi(CloudResponse.self, "/v1/cloud/get", ["limit": limit, "offset": offset])
    }

    static func cloudDelete(id: Int) async throws {
        _ = try await eapi(CodeOnly.self, "/cloud/del", ["songIds": "[\(id)]"])
    }

    /// `startplay` weblog — writes the song into the 最近播放 (recent-plays)
    /// list. The service needs this *and* the `play` weblog; sending only `play`
    /// (as before) bumped the listening ranking but never wrote 最近播放 (#33).
    static func scrobbleStart(trackID: Int, sourceID: Int) async {
        await sendWeblog([[
            "action": "startplay",
            "json": [
                "id": trackID, "type": "song",
                "mainsite": "1", "mainsiteWeb": "1",
                "content": "id=\(sourceID)",
            ],
        ]])
    }

    /// `play` weblog — increments the listening-ranking play count and time.
    static func scrobbleFinish(trackID: Int, sourceID: Int, seconds: Int) async {
        await sendWeblog([[
            "action": "play",
            "json": [
                "download": 0, "end": "playend", "id": trackID,
                "sourceId": String(sourceID), "time": seconds,
                "type": "song", "wifi": 0, "source": "list",
                "mainsite": "1", "mainsiteWeb": "1",
                "content": "id=\(sourceID)",
            ],
        ]])
    }

    /// Routed via eapi with the desktop-client cookie (`os=osx`) to match the
    /// reference scrobble implementation.
    private static func sendWeblog(_ log: [[String: Any]]) async {
        guard let data = try? JSONSerialization.data(withJSONObject: log),
              let logs = String(data: data, encoding: .utf8) else { return }
        _ = try? await client.eapi("/feedback/weblog", ["logs": logs],
                                   cookieOverrides: ["os": "osx"])
    }

    // MARK: - Playlists

    struct PersonalizedResponse: Decodable {
        let result: [PlaylistSummary]
    }

    static func personalizedPlaylists(limit: Int = 30) async throws -> [PlaylistSummary] {
        try await eapi(PersonalizedResponse.self, "/personalized/playlist",
                       ["limit": limit, "total": true, "n": 1000]).result
    }

    struct RecommendResourceResponse: Decodable {
        let recommend: [PlaylistSummary]
    }

    /// Logged-in daily recommended playlists.
    static func recommendResource() async throws -> [PlaylistSummary] {
        try await eapi(RecommendResourceResponse.self, "/v1/discovery/recommend/resource").recommend
    }

    // MARK: - Homepage recommendation blocks

    /// `/homepage/block/page`：网易云首页「推荐」的板块。标题、顺序、内容全部由服务端下发，
    /// 所以板块列表跟着账号走（登录后才会出现「根据…为你推荐」这类个性化板块）。
    struct HomePageResponse: Decodable {
        let data: Payload?

        struct Payload: Decodable {
            let blocks: [Block]?
        }

        struct Block: Decodable {
            let blockCode: String?
            let uiElement: UIElement?
            let creatives: [Creative]?

            /// 板块标题：服务端有时给 subTitle，有时只给 mainTitle。
            var title: String? {
                [uiElement?.subTitle?.title, uiElement?.mainTitle?.title]
                    .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty }
            }

            /// 同一板块内按「类型+id」去重：服务端会在多个 creative 里重复同一张歌单。
            var resources: [Creative.Resource] {
                var seen = Set<String>()
                return (creatives ?? []).flatMap { $0.resources ?? [] }
                    .filter { seen.insert($0.dedupeKey).inserted }
            }
        }

        struct UIElement: Decodable {
            struct Title: Decodable { let title: String? }
            struct Image: Decodable { let imageUrl: String? }

            let mainTitle: Title?
            let subTitle: Title?
            let image: Image?
        }

        struct Creative: Decodable {
            let resources: [Resource]?

            struct Resource: Decodable {
                let resourceType: String?
                let resourceId: IdText?
                let uiElement: UIElement?
                let resourceExtInfo: Ext?

                struct Ext: Decodable {
                    let playCount: Int?
                    let song: Track?
                }

                /// 服务端的 resourceId 有时是字符串、有时是数字。
                struct IdText: Decodable {
                    let text: String

                    init(from decoder: Decoder) throws {
                        let container = try decoder.singleValueContainer()
                        if let string = try? container.decode(String.self) {
                            text = string
                        } else if let number = try? container.decode(Int64.self) {
                            text = String(number)
                        } else {
                            text = ""
                        }
                    }
                }

                var id: Int { Int(resourceId?.text ?? "") ?? 0 }
                var dedupeKey: String { "\(resourceType ?? "")|\(resourceId?.text ?? "")" }
                var song: Track? { resourceExtInfo?.song }
                var title: String? { uiElement?.mainTitle?.title }
                var subtitle: String? { uiElement?.subTitle?.title }
                var coverURL: String? { uiElement?.image?.imageUrl }
            }
        }
    }

    static func homepageBlocks() async throws -> [HomePageResponse.Block] {
        let response = try await eapi(HomePageResponse.self, "/homepage/block/page",
                                      ["refresh": false, "cursor": ""])
        return response.data?.blocks ?? []
    }

    struct RecommendSongsResponse: Decodable {
        struct Body: Decodable {
            let dailySongs: [Track]?
        }

        // New accounts with no listening history get `"data": null`.
        let data: Body?
    }

    static func dailyRecommendSongs() async throws -> [Track] {
        let resp = try await eapi(RecommendSongsResponse.self, "/v3/discovery/recommend/songs")
        return resp.data?.dailySongs ?? []
    }

    struct RecommendDislikeResponse: Decodable {
        let data: Track

        private enum CodingKeys: String, CodingKey {
            case data
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let track = try container.decode(Track.self, forKey: .data)
            guard track.id > 0,
                  !track.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw DecodingError.dataCorruptedError(
                    forKey: .data,
                    in: container,
                    debugDescription: "Recommendation replacement is incomplete"
                )
            }
            data = track
        }
    }

    static func dislikeRecommendedSong(id: Int) async throws -> Track {
        try await eapi(
            RecommendDislikeResponse.self,
            "/v2/discovery/recommend/dislike",
            ["resId": id, "resType": 4, "sceneType": 1]
        ).data
    }

    static func addToMusicBlacklist(_ target: MusicBlacklistTarget,
                                    using client: MusicClient = .shared) async throws {
        guard client.isLoggedIn else { throw MusicAPIError.needLogin }
        let type: String
        let id: Int
        switch target {
        case .song(let songID):
            type = "song"
            id = songID
        case .artist(let artistID):
            type = "artist"
            id = artistID
        }
        guard id > 0 else {
            throw MusicAPIError.business(code: 400, message: String(localized: "无法识别这项音乐内容"))
        }
        let data = try await client.eapi("/music-blacklist/add",
                                         ["contentType": type, "contentIdList": [String(id)]])
        _ = try client.decoded(CodeOnly.self, from: data)
    }

    // MARK: - Comments

    /// The comment thread of a song.
    static func songCommentThread(songID: Int) -> String { "R_SO_4_\(songID)" }

    /// A page of a song's latest comments from `offset`, and on the first
    /// page its hot comments too.
    static func songComments(songID: Int, limit: Int = 20, offset: Int = 0,
                             using client: MusicClient = .shared) async throws -> SongCommentsPage {
        guard songID > 0 else {
            throw MusicAPIError.business(code: 400, message: String(localized: "无法识别这首歌曲"))
        }
        let data = try await client.eapi("/v1/resource/comments/\(songCommentThread(songID: songID))",
                                         ["limit": limit, "offset": offset])
        return try client.decoded(SongCommentsPage.self, from: data)
    }

    /// Likes a comment for the signed-in listener, or takes the like back.
    static func likeComment(threadID: String, commentID: Int, like: Bool,
                            using client: MusicClient = .shared) async throws {
        guard client.isLoggedIn else { throw MusicAPIError.needLogin }
        guard commentID > 0 else {
            throw MusicAPIError.business(code: 400, message: String(localized: "无法识别这条评论"))
        }
        let data = try await client.eapi(like ? "/v1/comment/like" : "/v1/comment/unlike",
                                         ["threadId": threadID, "commentId": String(commentID)])
        _ = try client.decoded(CodeOnly.self, from: data)
    }

    struct PlaylistDetailResponse: Decodable {
        let playlist: PlaylistDetail
        let privileges: [TrackPrivilege]?
    }

    static func playlistDetail(id: Int) async throws -> PlaylistDetailResponse {
        try await eapi(PlaylistDetailResponse.self, "/v6/playlist/detail",
                       ["id": id, "n": 100_000, "s": 8])
    }

    struct PlaylistBrief: Decodable {
        struct Body: Decodable {
            let id: Int
            let name: String?
            let coverImgUrl: String?
        }

        let playlist: Body
    }

    /// Lightweight name + cover fetch (used for the personalized radar playlists,
    /// whose title/artwork are generated per account).
    static func playlistBrief(id: Int) async throws -> PlaylistBrief.Body {
        try await eapi(PlaylistBrief.self, "/v6/playlist/detail", ["id": id, "n": 1, "s": 0]).playlist
    }

    struct SongDetailResponse: Decodable {
        let songs: [Track]
        let privileges: [TrackPrivilege]?
    }

    /// Through the eapi, as the desktop client reads song details: the web
    /// API's privileges call some VIP songs taken down (`st` -100) for
    /// subscribers, whom the eapi streams them to.
    static func songDetails(ids: [Int]) async throws -> SongDetailResponse {
        guard !ids.isEmpty else { return SongDetailResponse(songs: [], privileges: []) }
        let c = "[" + ids.map { "{\"id\":\($0)}" }.joined(separator: ",") + "]"
        return try await eapi(SongDetailResponse.self, "/v3/song/detail", ["c": c])
    }

    struct TopPlaylistResponse: Decodable {
        let playlists: [PlaylistSummary]
        let total: Int?
        let more: Bool?
    }

    static func topPlaylists(category: String, order: String = "hot",
                             limit: Int = 50, offset: Int = 0) async throws -> TopPlaylistResponse {
        try await eapi(TopPlaylistResponse.self, "/playlist/list",
                       ["cat": category, "order": order, "limit": limit, "offset": offset, "total": true])
    }

    struct HighQualityResponse: Decodable {
        let playlists: [PlaylistSummary]
        let lasttime: Int?
        let more: Bool?
    }

    static func highQualityPlaylists(category: String = "全部", limit: Int = 50,
                                     before: Int = 0) async throws -> HighQualityResponse {
        try await eapi(HighQualityResponse.self, "/playlist/highquality/list",
                       ["cat": category, "limit": limit, "lasttime": before, "total": true])
    }

    struct ToplistResponse: Decodable {
        let list: [ToplistItem]
    }

    static func toplists() async throws -> [ToplistItem] {
        try await eapi(ToplistResponse.self, "/toplist").list
    }

    struct PlaylistCreateResponse: Decodable {
        let code: Int
        let id: Int?
    }

    @discardableResult
    static func createPlaylist(name: String, isPrivate: Bool) async throws -> Int? {
        try await eapi(PlaylistCreateResponse.self, "/playlist/create",
                       ["name": name, "privacy": isPrivate ? 10 : 0, "type": "NORMAL"]).id
    }

    static func updatePlaylistDescription(id: Int, description: String, binding: String) async throws {
        guard id > 0, description.utf16.count <= 1000 else { throw MusicAPIError.decoding("Invalid playlist description") }
        _ = try await eapi(CodeOnly.self, "/playlist/desc/update", ["id": id, "desc": description],
                           requiringAuthentication: binding)
    }

    private struct PlaylistUploadSlot: Decodable {
        struct Body: Decodable {
            let objectKey: String
            let token: String
            let docId: String
            let numericDocId: UInt64?

            private enum CodingKeys: String, CodingKey { case objectKey, token, docId }

            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                objectKey = try c.decode(String.self, forKey: .objectKey)
                token = try c.decode(String.self, forKey: .token)
                if let text = try? c.decode(String.self, forKey: .docId) {
                    docId = text
                    numericDocId = nil
                } else {
                    let value = try c.decode(UInt64.self, forKey: .docId)
                    docId = String(value)
                    numericDocId = value
                }
            }
        }
        let result: Body
    }

    private struct PlaylistCoverResponse: Decodable {
        let code: Int
        let url: String?
    }

    private enum CoverSaveError: LocalizedError {
        case credentials, upload, commit
        var errorDescription: String? {
            switch self {
            case .credentials: String(localized: "获取封面上传凭证失败，请重试")
            case .upload: String(localized: "图片上传失败，请重试")
            case .commit: String(localized: "更新歌单封面失败，请重试")
            }
        }
    }

    static func updatePlaylistCover(id: Int, jpeg: Data, binding: String) async throws -> String {
        guard id > 0, !jpeg.isEmpty, jpeg.count <= 768 * 1024 else { throw MusicAPIError.decoding("Invalid playlist cover") }
        let slotPayload: [String: Any] = [
            "bucket": "yyimgs", "ext": "jpg", "filename": "playlist.jpg", "local": false,
            "nos_product": 0, "type": "other", "return_body": #"{"code":200,"size":"$(ObjectSize)"}"#
        ]
        let slot: PlaylistUploadSlot.Body
        do {
            // eapi 优先（App 通道签发的 token 与 eapi 登录态同源），weapi 兜底。
            // eapi / weapi 都可能下发 token；只认纯 ASCII（中间允许一个空格）、id 合法的那个。
            func usable(_ value: PlaylistUploadSlot?) -> Bool {
                guard let body = value?.result else { return false }
                let trimmed = body.token.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty
                    && trimmed.range(of: "^[!-~](?:[ -~]{0,4094}[!-~])?$", options: .regularExpression) != nil
                    && body.docId.range(of: "^[0-9]{1,24}$", options: .regularExpression) != nil
            }
            var allocated: PlaylistUploadSlot?
            do {
                let data = try await client.eapi("/nos/token/alloc", slotPayload)
                allocated = try? client.decoded(PlaylistUploadSlot.self, from: data)
            } catch is CancellationError { throw CancellationError() }
            catch { allocated = nil }
            if !usable(allocated) {
                let data = try await client.playlistCoverWebRequest("/nos/token/alloc", slotPayload, binding: binding)
                allocated = try client.decoded(PlaylistUploadSlot.self, from: data)
            }
            guard usable(allocated), let value = allocated else { throw CoverSaveError.credentials }
            slot = value.result
        } catch is CancellationError { throw CancellationError() }
        catch { throw CoverSaveError.credentials }
        guard let path = MusicClient.playlistCoverPath(slot.objectKey),
              slot.docId.range(of: "^[0-9]{1,24}$", options: .regularExpression) != nil else {
            throw CoverSaveError.credentials
        }
        do {
            try await client.uploadPlaylistCoverJPEG(jpeg, path: path, token: slot.token, binding: binding)
        } catch is CancellationError { throw CancellationError() }
        catch { throw CoverSaveError.upload }
        let result: PlaylistCoverResponse
        do {
            let coverIdentifier: Any = slot.numericDocId.map { NSNumber(value: $0) as Any } ?? slot.docId
            let data = try await client.playlistCoverWebRequest("/playlist/cover/update",
                                                                 ["id": id, "coverImgId": coverIdentifier], binding: binding)
            result = try client.decoded(PlaylistCoverResponse.self, from: data)
        } catch is CancellationError { throw CancellationError() }
        catch { throw CoverSaveError.commit }
        if let url = result.url, var parts = URLComponents(string: url),
           let host = parts.host, host.hasSuffix(".music.126.net"), parts.user == nil,
           parts.password == nil, parts.port == nil, ["http", "https"].contains(parts.scheme ?? "") {
            parts.scheme = "https"
            if let url = parts.url { return url.absoluteString }
        }
        return "https://p1.music.126.net/" + path
    }

    static func deletePlaylist(id: Int, binding: String? = nil) async throws {
        _ = try await eapi(CodeOnly.self, "/playlist/remove", ["ids": "[\(id)]"], requiringAuthentication: binding)
    }

    static func subscribePlaylist(id: Int, subscribe: Bool) async throws {
        _ = try await eapi(CodeOnly.self, "/playlist/\(subscribe ? "subscribe" : "unsubscribe")", ["id": id])
    }

    struct ManipulateResponse: Decodable {
        let code: Int?
    }

    static func playlistTracks(op: String, playlistID: Int, trackIDs: [Int]) async throws {
        let ids = "[" + trackIDs.map(String.init).joined(separator: ",") + "]"
        let data = try await client.eapi("/playlist/manipulate/tracks",
                                         ["op": op, "pid": playlistID, "trackIds": ids, "imme": "true"])
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = obj["code"] as? Int, code != 200 {
            // 512: already-in-playlist quirk — retry with doubled ids like the reference impl
            if code == 512, op == "add" {
                let doubled = "[" + (trackIDs + trackIDs).map(String.init).joined(separator: ",") + "]"
                _ = try await client.eapi("/playlist/manipulate/tracks",
                                          ["op": op, "pid": playlistID, "trackIds": doubled, "imme": "true"])
                return
            }
            throw MusicAPIError.business(code: code, message: obj["message"] as? String)
        }
    }

    struct IntelligenceResponse: Decodable {
        struct Item: Decodable {
            let songInfo: Track?
            let id: Int?
        }

        let data: [Item]?
    }

    /// 心动模式 — generates a heartbeat-mode queue from a seed song in a playlist.
    static func intelligenceList(songID: Int, playlistID: Int) async throws -> [Track] {
        let resp = try await eapi(IntelligenceResponse.self, "/playmode/intelligence/list",
                                  ["songId": songID, "type": "fromPlayOne",
                                   "playlistId": playlistID, "startMusicId": songID, "count": 1])
        return (resp.data ?? []).compactMap(\.songInfo)
    }

    // MARK: - Tracks

    struct SongURLResponse: Decodable {
        let data: [SongURLData]
    }

    static func songURL(ids: [Int], level: String, using client: MusicClient = .shared) async throws -> [SongURLData] {
        let idString = "[" + ids.map(String.init).joined(separator: ",") + "]"
        var payload: [String: Any] = ["ids": idString, "level": level, "encodeType": "flac"]
        if level == "sky" { payload["immerseType"] = "c51" }
        let data = try await client.eapi("/song/enhance/player/url/v1", payload)
        return try client.decoded(SongURLResponse.self, from: data).data
    }

    /// `songURL`, asked once more after a moment when the request dies in
    /// transit. The first request after the app sat idle often lands on a
    /// pooled connection the server already closed; URLSession retries a GET
    /// on its own but not this POST, so the first song played failed with
    /// 无法播放 while a second try a moment later worked (#210). Reading a
    /// playback URL changes nothing, so asking twice is safe.
    static func songURLRetrying(ids: [Int], level: String, using client: MusicClient = .shared,
                                retryDelay: Duration = .milliseconds(400)) async throws -> [SongURLData] {
        do {
            return try await songURL(ids: ids, level: level, using: client)
        } catch where TransientRequestFailure.matches(error) {
            try await Task.sleep(for: retryDelay)
            return try await songURL(ids: ids, level: level, using: client)
        }
    }

    /// Download eligibility is resolved independently of the playback URL.
    /// An injectable client lets the compatibility probe use an isolated cookie
    /// jar without reading or changing the listener's current login.
    static func songDownloadResource(track: Track, level: String, accountScope: String,
                                     client: MusicClient = .shared) async throws -> OfflineAudioResource {
        let data = try await songDownloadURL(id: track.id, level: level, client: client)
        return try downloadResource(data: data, track: track, accountScope: accountScope)
    }

    static func songDownloadURL(id: Int, level: String, client: MusicClient = .shared) async throws -> SongURLData {
        struct Response: Decodable { let data: SongURLData? }
        var payload: [String: Any] = ["id": id, "level": level, "immerseType": "c51"]
        let body = try await client.eapi("/song/enhance/download/url/v1", payload)
        let response = try client.decoded(Response.self, from: body)
        guard let data = response.data else { throw OfflineAudioError.unavailable }
        return data
    }

    static func downloadResource(data: SongURLData, track: Track, accountScope: String) throws -> OfflineAudioResource {
        guard data.id == track.id, data.code == 200, data.freeTrialInfo == nil,
              let md5 = data.md5?.lowercased(), let quality = data.level,
              let format = data.type.flatMap({ OfflineAudioFormat(rawValue: $0.lowercased()) }),
              let rawURL = data.url, var components = URLComponents(string: rawURL),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.host != nil else { throw OfflineAudioError.unavailable }
        components.scheme = "https"
        guard let url = components.url else { throw OfflineAudioError.invalidResource }
        // Some download responses omit time, and some songs (cloud drive,
        // simplified entries) omit dt. Whichever is known supplies the duration;
        // when both are, they must agree, which also rejects a trial URL.
        let responseDuration = data.time > 0 ? Double(data.time) / 1000 : 0
        if responseDuration > 0, track.duration > 0, abs(responseDuration - track.duration) > max(2, track.duration * 0.03) {
            throw OfflineAudioError.invalidAudio
        }
        let duration = track.duration > 0 ? track.duration : responseDuration
        guard duration > 0 else { throw OfflineAudioError.unavailable }
        let identity = OfflineAudioIdentity(accountScope: accountScope, trackID: track.id, source: Upstream.tag,
                                            quality: quality, format: format, contentMD5: md5)
        let descriptor = OfflineAudioDescriptor(identity: identity, byteCount: Int64(data.size), duration: duration)
        try descriptor.validate()
        return OfflineAudioResource(descriptor: descriptor, url: url)
    }

    static func lyric(id: Int) async throws -> LyricResponse {
        // `/song/lyric/v1` also returns verbatim (word-by-word) `yrc`. Fall back
        // to the classic endpoint if it yields nothing usable, so plain lyrics
        // never regress.
        if let v1 = try? await eapi(LyricResponse.self, "/song/lyric/v1",
            ["id": id, "cp": false,
             "lv": 0, "kv": 0, "tv": 0, "rv": 0, "yv": 0, "ytv": 0, "yrv": 0]),
            (v1.lrc?.lyric?.isEmpty == false) || (v1.yrc?.lyric?.isEmpty == false) {
            return v1
        }
        try Task.checkCancellation()
        return try await eapi(LyricResponse.self, "/song/lyric",
                              ["id": id, "lv": -1, "kv": -1, "tv": -1, "rv": -1])
    }

    struct FMResponse: Decodable {
        let data: [Track]?
    }

    static func personalFM() async throws -> [Track] {
        try await eapi(FMResponse.self, "/v1/radio/get").data ?? []
    }

    /// Through the eapi, as the like above: the same radio endpoints, the
    /// same risk control.
    static func fmTrash(id: Int) async throws {
        _ = try await eapi(CodeOnly.self, "/radio/trash/add",
                           ["alg": "RT", "songId": String(id), "time": "25"])
    }

    struct SimiSongResponse: Decodable {
        let songs: [Track]
    }

    static func similarSongs(id: Int, limit: Int = 30) async throws -> [Track] {
        try await eapi(SimiSongResponse.self, "/v1/discovery/simiSong",
                       ["songid": id, "limit": limit, "offset": 0]).songs
    }

    // MARK: - Albums

    static func album(id: Int) async throws -> AlbumDetailResponse {
        try await eapi(AlbumDetailResponse.self, "/v1/album/\(id)")
    }

    struct NewAlbumsResponse: Decodable {
        let albums: [AlbumSummary]
    }

    static func newAlbums(area: String = "ALL", limit: Int = 30, offset: Int = 0) async throws -> [AlbumSummary] {
        try await eapi(NewAlbumsResponse.self, "/album/new",
                       ["area": area, "limit": limit, "offset": offset, "total": true]).albums
    }

    struct AlbumDynamicResponse: Decodable {
        let isSub: Bool?
        let subCount: Int?
    }

    static func albumDynamic(id: Int) async throws -> AlbumDynamicResponse {
        try await eapi(AlbumDynamicResponse.self, "/album/detail/dynamic", ["id": id])
    }

    static func subscribeAlbum(id: Int, subscribe: Bool) async throws {
        _ = try await eapi(CodeOnly.self, "/album/\(subscribe ? "sub" : "unsub")", ["id": id])
    }

    // MARK: - Artists

    struct ArtistResponse: Decodable {
        let artist: ArtistSummary
        let hotSongs: [Track]
    }

    static func artist(id: Int) async throws -> ArtistResponse {
        try await eapi(ArtistResponse.self, "/v1/artist/\(id)")
    }

    struct ArtistAlbumsResponse: Decodable {
        let hotAlbums: [AlbumSummary]
        let more: Bool?
    }

    static func artistAlbums(id: Int, limit: Int = 100, offset: Int = 0) async throws -> ArtistAlbumsResponse {
        try await eapi(ArtistAlbumsResponse.self, "/artist/albums/\(id)",
                       ["limit": limit, "offset": offset, "total": true])
    }

    static func subscribeArtist(id: Int, subscribe: Bool) async throws {
        // Through the web API: through the eapi, following is refused with
        // -460, though unfollowing is not.
        let data = try await client.api("/artist/\(subscribe ? "sub" : "unsub")",
                                        ["artistId": String(id), "artistIds": "[\(id)]"])
        _ = try client.decoded(CodeOnly.self, from: data)
    }

    struct ToplistArtistResponse: Decodable {
        struct Body: Decodable {
            let artists: [ArtistSummary]
        }

        let list: Body
    }

    static func topArtists(limit: Int = 100) async throws -> [ArtistSummary] {
        try await eapi(ToplistArtistResponse.self, "/toplist/artist",
                       ["type": 1, "limit": limit, "offset": 0, "total": true]).list.artists
    }

    struct SimiArtistResponse: Decodable {
        let artists: [ArtistSummary]
    }

    static func similarArtists(id: Int) async throws -> [ArtistSummary] {
        try await eapi(SimiArtistResponse.self, "/discovery/simiArtist", ["artistid": id]).artists
    }

    // MARK: - Search

    enum SearchType: Int {
        case songs = 1
        case albums = 10
        case artists = 100
        case playlists = 1000
    }

    struct SearchResult: Decodable {
        let songs: [Track]?
        let albums: [AlbumSummary]?
        let artists: [ArtistSummary]?
        let playlists: [PlaylistSummary]?
        let songCount: Int?
        let albumCount: Int?
        let artistCount: Int?
        let playlistCount: Int?
    }

    struct SearchResponse: Decodable {
        let result: SearchResult?
    }

    static func search(_ keywords: String, type: SearchType,
                       limit: Int = 30, offset: Int = 0) async throws -> SearchResult {
        let resp = try await eapi(SearchResponse.self, "/cloudsearch/pc",
                                  ["s": keywords, "type": type.rawValue,
                                   "limit": limit, "offset": offset, "total": true])
        return resp.result ?? SearchResult(songs: nil, albums: nil, artists: nil, playlists: nil,
                                           songCount: nil, albumCount: nil, artistCount: nil, playlistCount: nil)
    }

    struct SearchSuggestResponse: Decodable {
        struct Body: Decodable {
            let songs: [Track]?
            let artists: [ArtistSummary]?
            let albums: [AlbumSummary]?
            let playlists: [PlaylistSummary]?
        }

        let result: Body?
    }

    static func searchSuggest(_ keywords: String) async throws -> SearchSuggestResponse.Body? {
        try await eapi(SearchSuggestResponse.self, "/search/suggest/web", ["s": keywords]).result
    }

    struct SearchDefaultResponse: Decodable {
        struct Body: Decodable {
            let showKeyword: String?
            let realkeyword: String?
        }

        let data: Body?
    }

    static func searchDefaultKeyword() async throws -> String? {
        try await eapi(SearchDefaultResponse.self, "/search/defaultkeyword/get").data?.showKeyword
    }

    // MARK: - Personalized extras

    struct PersonalizedNewsongResponse: Decodable {
        struct Item: Decodable {
            let id: Int
            let name: String?
            let song: Track?
        }

        let result: [Item]
    }

    /// 热歌榜（3778678）的歌曲，24 首。
    /// 「近期云村热播」「最近的热门歌曲」两个板块的兜底数据源；
    /// `/top/song` 在 eapi 下取不到（服务端回「接口未找到！」），所以走榜单详情。
    static func hotChartSongs(limit: Int = 24) async throws -> [Track] {
        let response = try await playlistDetail(id: 3_778_678)
        return Array(response.playlist.tracks.prefix(limit))
    }

    static func personalizedNewSongs(limit: Int = 10) async throws -> [Track] {
        let resp = try await eapi(PersonalizedNewsongResponse.self, "/personalized/newsong",
                                  ["type": "recommend", "limit": limit, "areaId": 0])
        return resp.result.compactMap(\.song)
    }
}

// MARK: - 听歌排行 / 私信
//
// 接口与数据形状照搬备用源码 MeloX（`NeteaseAPI+UserPlayRecords`、`NeteaseSocialAPI`）：
// 排行榜 `/v1/play/record`（type=1 最近一周、type=0 所有时间），
// 私信 `/msg/private/{users,history,send}`。这里只做文本消息，不解析分享资源。

struct PlayRecord: Decodable, Hashable {
    let song: Track
    let playCount: Int

    enum CodingKeys: String, CodingKey { case song, playCount }
}

struct PlayRecordsResponse: Decodable {
    let weekData: [PlayRecord]?
    let allData: [PlayRecord]?
}

/// 私信里出现的人（会话两端、消息收发都用这个形状）。
struct MessageContact: Decodable, Hashable {
    let userId: Int?
    let nickname: String?
    let avatarUrl: String?
    let remarkName: String?

    /// 备注优先，其次昵称；都没有时用占位名。
    var displayName: String {
        if let remark = remarkName?.trimmingCharacters(in: .whitespacesAndNewlines), !remark.isEmpty {
            return remark
        }
        if let nickname, !nickname.isEmpty { return nickname }
        return String(localized: "网易云用户")
    }

    private enum CodingKeys: String, CodingKey {
        case userId, nickname, avatarUrl, remarkName
    }
}

struct PrivateConversation: Decodable, Hashable, Identifiable {
    let fromUser: MessageContact?
    let toUser: MessageContact?
    let lastMsgTime: Int64?
    /// 服务端给的是 JSON 字符串（`{"msg":"…"}`），解析失败时当纯文本。
    let lastMsg: String?
    let newMsgCount: Int?

    var id: String {
        [fromUser?.userId ?? 0, toUser?.userId ?? 0]
            .sorted()
            .map(String.init)
            .joined(separator: "-")
    }

    /// 会话对方（不是自己的那一端）。
    func peer(currentUserID: Int) -> MessageContact? {
        if let fromUser, fromUser.userId != currentUserID { return fromUser }
        if let toUser, toUser.userId != currentUserID { return toUser }
        return fromUser ?? toUser
    }

    private enum CodingKeys: String, CodingKey {
        case fromUser, toUser
        case lastMsgTime = "lastMsgTime"
        case lastMsg
        case newMsgCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fromUser = try c.decodeIfPresent(MessageContact.self, forKey: .fromUser)
        toUser = try c.decodeIfPresent(MessageContact.self, forKey: .toUser)
        lastMsgTime = try c.decodeIfPresent(Int64.self, forKey: .lastMsgTime)
        lastMsg = try c.decodeIfPresent(String.self, forKey: .lastMsg)
        newMsgCount = try c.decodeIfPresent(Int.self, forKey: .newMsgCount)
    }
}

struct PrivateMessage: Decodable, Hashable {
    let messageID: Int64
    let fromUser: MessageContact?
    let toUser: MessageContact?
    let time: Int64?
    /// 同样是 JSON 字符串包裹的正文。
    let msg: String?

    func isOutgoing(currentUserID: Int) -> Bool { fromUser?.userId == currentUserID }

    var text: String { PrivateMessagePayload.text(from: msg) }

    private enum CodingKeys: String, CodingKey {
        case fromUser, toUser, time, msg, id
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fromUser = try c.decodeIfPresent(MessageContact.self, forKey: .fromUser)
        toUser = try c.decodeIfPresent(MessageContact.self, forKey: .toUser)
        time = try c.decodeIfPresent(Int64.self, forKey: .time)
        msg = try c.decodeIfPresent(String.self, forKey: .msg)
        messageID = (try? c.decodeIfPresent(Int64.self, forKey: .id)) as? Int64 ?? (time ?? 0)
    }
}

/// 私信正文解码：服务端把内容存成 `{"msg":"…","song":{…}}` 这样的字符串。
enum PrivateMessagePayload {
    static func text(from raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        guard let data = raw.data(using: .utf8),
              let wire = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return raw
        }
        if let text = (wire["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        if let song = wire["song"] as? [String: Any], let name = song["name"] as? String {
            return String(localized: "歌曲") + " · " + name
        }
        if let playlist = wire["playlist"] as? [String: Any], let name = playlist["name"] as? String {
            return String(localized: "歌单") + " · " + name
        }
        if let album = wire["album"] as? [String: Any], let name = album["name"] as? String {
            return String(localized: "专辑") + " · " + name
        }
        return String(localized: "消息")
    }
}

private struct PrivateConversationsResponse: Decodable {
    let msgs: [PrivateConversation]?
}

private struct PrivateHistoryResponse: Decodable {
    let msgs: [PrivateMessage]?
}

extension MusicAPI {
    static func userPlayRecords(userID: Int, week: Bool) async throws -> [PlayRecord] {
        let response = try await eapi(
            PlayRecordsResponse.self,
            "/v1/play/record",
            ["uid": userID, "type": week ? 1 : 0]
        )
        return ((week ? response.weekData : response.allData) ?? []).filter { $0.song.id > 0 }
    }

    static func privateConversations(binding: String) async throws -> [PrivateConversation] {
        let response = try await eapi(
            PrivateConversationsResponse.self,
            "/msg/private/users",
            ["offset": 0, "limit": 50, "total": true], requiringAuthentication: binding
        )
        return response.msgs ?? []
    }

    static func privateHistory(userID: Int, before: Int64? = nil, binding: String) async throws -> [PrivateMessage] {
        // 首次加载传 time = -1：这个请求同时承担服务端已读上报（0 只会拿历史，不清未读）。
        let response = try await eapi(
            PrivateHistoryResponse.self,
            "/msg/private/history",
            ["userId": userID, "limit": 100, "time": before ?? -1, "total": true],
            requiringAuthentication: binding
        )
        return (response.msgs ?? []).sorted { ($0.time ?? 0) < ($1.time ?? 0) }
    }

    static func sendPrivateText(_ text: String, to userID: Int, binding: String) async throws {
        _ = try await eapi(
            CodeOnly.self,
            "/msg/private/send",
            ["type": "text", "msg": text, "userIds": "[\(userID)]"], requiringAuthentication: binding
        )
    }
}

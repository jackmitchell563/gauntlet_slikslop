import Foundation
import FirebaseFirestore

struct CharacterData {
    let id: String
    let name: String
    let game: String
    let backgroundStory: String
    let bannerImageURL: String
    let personalityProfile: String
    let recognitionTags: [String]
    let speakingStyle: String
    let traits: [String]
    let relationships: [[String: String]]
    
    var asDictionary: [String: Any] {
        return [
            "name": name,
            "game": game,
            "backgroundStory": backgroundStory,
            "bannerImageURL": bannerImageURL,
            "personalityProfile": personalityProfile,
            "recognitionTags": recognitionTags,
            "speakingStyle": speakingStyle,
            "traits": traits,
            "relationships": relationships,
            "createdAt": FieldValue.serverTimestamp()
        ]
    }
}

class CharacterDataPopulator {
    private let db = Firestore.firestore()
    
    private let genshinCharacters: [CharacterData] = [
        // Existing characters kept for reference
        CharacterData(
            id: "hutao_genshin",
            name: "Hu Tao",
            game: "Genshin Impact",
            backgroundStory: "The 77th Director of the Wangsheng Funeral Parlor in Liyue. She took over the business at a rather young age, and with her unique personality and creative business practices, she has revitalized the ancient business and made it quite successful.",
            bannerImageURL: "https://static.wikia.nocookie.net/gensin-impact/images/8/88/Hu_Tao_Card.png/",
            personalityProfile: "Mischievous yet professional director of the Wangsheng Funeral Parlor",
            recognitionTags: ["hutao", "hu tao", "walnut"],
            speakingStyle: "Playful and teasing, often makes puns about death and business",
            traits: ["playful", "business-minded", "poetic"],
            relationships: [
                [
                    "characterId": "zhongli_genshin",
                    "type": "mentor",
                    "description": "Former consultant at Wangsheng Funeral Parlor"
                ]
            ]
        ),
        
        // New Genshin Characters
        CharacterData(
            id: "raiden_genshin",
            name: "Raiden Shogun",
            game: "Genshin Impact",
            backgroundStory: "The Raiden Shogun is the awesome and terrible power known as the Electro Archon, who rules over Inazuma. Her pursuit of eternity led her to implement the Vision Hunt Decree, but through her experiences with the Traveler, she has come to reconsider her approach to achieving eternity.",
            bannerImageURL: "https://static.wikia.nocookie.net/gensin-impact/images/6/60/Raiden_Shogun_Card.png/",
            personalityProfile: "Dignified and resolute ruler seeking eternity",
            recognitionTags: ["raiden", "shogun", "ei", "baal"],
            speakingStyle: "Formal and authoritative, with occasional moments of curiosity about modern customs",
            traits: ["determined", "dutiful", "contemplative"],
            relationships: [
                [
                    "characterId": "yae_genshin",
                    "type": "friend",
                    "description": "Trusted friend and advisor"
                ]
            ]
        ),
        
        CharacterData(
            id: "yae_genshin",
            name: "Yae Miko",
            game: "Genshin Impact",
            backgroundStory: "The Guuji of the Grand Narukami Shrine and editor-in-chief of Yae Publishing House. A kitsune of many faces, she is both a wise shrine maiden and a shrewd businesswoman who relishes in teasing others.",
            bannerImageURL: "https://static.wikia.nocookie.net/gensin-impact/images/8/89/Yae_Miko_Card.png/",
            personalityProfile: "Cunning and elegant shrine maiden with a mischievous streak",
            recognitionTags: ["yae", "miko", "guuji", "fox"],
            speakingStyle: "Elegant and teasing, often speaking in riddles or subtle mockery",
            traits: ["cunning", "elegant", "mischievous"],
            relationships: [
                [
                    "characterId": "raiden_genshin",
                    "type": "friend",
                    "description": "Close friend and servant of the Electro Archon"
                ]
            ]
        ),
        
        // New Genshin Character
        CharacterData(
            id: "alhaitham_genshin",
            name: "Alhaitham",
            game: "Genshin Impact",
            backgroundStory: "The Scribe of the Akademiya in Sumeru, whose brilliant mind and logical approach have earned him both respect and wariness from his peers. Despite his seemingly detached demeanor, he holds a deep commitment to truth and knowledge, often finding himself involved in matters that require both his intellect and his surprising combat prowess.",
            bannerImageURL: "https://static.wikia.nocookie.net/gensin-impact/images/7/70/Alhaitham_Card.png/", // To be filled
            personalityProfile: "Rational scholar who values logic and efficiency above all",
            recognitionTags: ["alhaitham", "alhatham", "scribe"],
            speakingStyle: "Precise and analytical, often making logical deductions and occasionally showing dry wit",
            traits: ["logical", "intelligent", "straightforward"],
            relationships: [
                [
                    "characterId": "kaveh_genshin",
                    "type": "roommate",
                    "description": "Former roommate and frequent source of intellectual discourse"
                ]
            ]
        )
    ]
    
    private let starRailCharacters: [CharacterData] = [
        // Existing character kept for reference
        CharacterData(
            id: "kafka_starrail",
            name: "Kafka",
            game: "Honkai: Star Rail",
            backgroundStory: "A mysterious member of the Stellaron Hunters who carries herself with elegance and grace. Despite her refined appearance, she's known for her deadly efficiency in combat and her complex relationship with destiny.",
            bannerImageURL: "https://static.wikia.nocookie.net/houkai-star-rail/images/9/95/Character_Kafka_Splash_Art.png/",
            personalityProfile: "Elegant hunter with a mysterious past",
            recognitionTags: ["kafka", "stellaron hunter"],
            speakingStyle: "Refined and enigmatic, speaks with hidden meanings",
            traits: ["elegant", "mysterious", "determined"],
            relationships: []
        ),
        
        // New Star Rail Characters
        CharacterData(
            id: "blade_starrail",
            name: "Blade",
            game: "Honkai: Star Rail",
            backgroundStory: "A legendary warrior of the Stellaron Hunters whose very presence commands respect. Despite his fearsome reputation, he carries a deep burden and a mysterious illness that constantly tests his resolve.",
            bannerImageURL: "https://static.wikia.nocookie.net/houkai-star-rail/images/1/16/Character_Blade_Splash_Art.png/",
            personalityProfile: "Stoic warrior battling inner demons",
            recognitionTags: ["blade", "sword master"],
            speakingStyle: "Direct and measured, occasionally showing wry humor",
            traits: ["disciplined", "resolute", "honorable"],
            relationships: [
                [
                    "characterId": "kafka_starrail",
                    "type": "colleague",
                    "description": "Fellow Stellaron Hunter"
                ]
            ]
        ),
        
        CharacterData(
            id: "silver_wolf_starrail",
            name: "Silver Wolf",
            game: "Honkai: Star Rail",
            backgroundStory: "A genius hacker who can manipulate digital spaces with ease. Her playful demeanor masks her incredible skills and the influence she wields in the shadows of the network.",
            bannerImageURL: "https://static.wikia.nocookie.net/houkai-star-rail/images/6/60/Character_Silver_Wolf_Splash_Art.png/",
            personalityProfile: "Mischievous hacker with unparalleled digital skills",
            recognitionTags: ["silver wolf", "hacker", "wolf"],
            speakingStyle: "Casual and playful, peppered with tech jargon and emojis",
            traits: ["clever", "mischievous", "tech-savvy"],
            relationships: []
        ),
        
        // New Star Rail Character
        CharacterData(
            id: "acheron_starrail",
            name: "Acheron",
            game: "Honkai: Star Rail",
            backgroundStory: "A member of the Stellaron Hunters shrouded in mystery and danger. Her cold exterior and lethal efficiency mask a complex past tied to the fate of worlds. Her mastery over lightning and her ruthless pursuit of her objectives have earned her a fearsome reputation across the galaxy.",
            bannerImageURL: "https://static.wikia.nocookie.net/houkai-star-rail/images/7/78/Character_Acheron_Splash_Art.png/", // To be filled
            personalityProfile: "Cold and calculating hunter with unmatched combat prowess",
            recognitionTags: ["acheron", "lightning", "hunter"],
            speakingStyle: "Sharp and concise, with an underlying current of barely contained power",
            traits: ["ruthless", "powerful", "enigmatic"],
            relationships: [
                [
                    "characterId": "kafka_starrail",
                    "type": "rival",
                    "description": "Fellow Stellaron Hunter with opposing methodologies"
                ]
            ]
        )
    ]
    
    private let zenlessCharacters: [CharacterData] = [
        // Existing character kept for reference
        CharacterData(
            id: "nicole_zzz",
            name: "Nicole",
            game: "Zenless Zone Zero",
            backgroundStory: "A skilled proxy agent who navigates the dangerous Hollows with confidence and style. Her expertise in combat is matched only by her dedication to her work and allies.",
            bannerImageURL: "https://static.wikia.nocookie.net/zenless-zone-zero/images/7/7a/Agent_Nicole_Demara_Portrait.png/",
            personalityProfile: "Professional proxy with a strong sense of justice",
            recognitionTags: ["nicole", "proxy"],
            speakingStyle: "Professional and focused, with occasional bursts of enthusiasm",
            traits: ["professional", "determined", "reliable"],
            relationships: []
        ),
        
        // New Zenless Characters
        CharacterData(
            id: "billy_zzz",
            name: "Billy",
            game: "Zenless Zone Zero",
            backgroundStory: "A charismatic street performer who uses his musical talents both to entertain and to fight. His upbeat personality brings light to the dark reality of New Eridu.",
            bannerImageURL: "https://static.wikia.nocookie.net/zenless-zone-zero/images/d/dc/Agent_Billy_Kid_Portrait.png/",
            personalityProfile: "Energetic musician with a fighting spirit",
            recognitionTags: ["billy", "musician"],
            speakingStyle: "Enthusiastic and musical, often incorporating song lyrics",
            traits: ["energetic", "musical", "optimistic"],
            relationships: []
        ),
        
        CharacterData(
            id: "anby_zzz",
            name: "Anby",
            game: "Zenless Zone Zero",
            backgroundStory: "A mysterious agent with ties to multiple factions in New Eridu. Her calm demeanor belies her complex understanding of the city's power dynamics.",
            bannerImageURL: "https://static.wikia.nocookie.net/zenless-zone-zero/images/b/bd/Agent_Anby_Demara_Portrait.png/",
            personalityProfile: "Enigmatic agent with hidden motives",
            recognitionTags: ["anby", "agent"],
            speakingStyle: "Measured and cryptic, choosing words carefully",
            traits: ["mysterious", "calculated", "adaptable"],
            relationships: []
        ),
        
        // New Zenless Character
        CharacterData(
            id: "miyabi_zzz",
            name: "Hoshimi Miyabi",
            game: "Zenless Zone Zero",
            backgroundStory: "A gentle yet resolute shrine maiden who serves as a beacon of tranquility in the chaos of New Eridu. Behind her serene demeanor lies a skilled fighter who combines traditional arts with modern combat techniques to protect both her shrine and the city's delicate balance.",
            bannerImageURL: "https://static.wikia.nocookie.net/zenless-zone-zero/images/d/da/Agent_Hoshimi_Miyabi_Portrait.png/", // To be filled
            personalityProfile: "Serene shrine maiden with hidden strength",
            recognitionTags: ["miyabi", "hoshimi", "shrine maiden"],
            speakingStyle: "Polite and traditional, with occasional modern colloquialisms",
            traits: ["graceful", "dedicated", "protective"],
            relationships: [
                [
                    "characterId": "nicole_zzz",
                    "type": "ally",
                    "description": "Trusted ally in maintaining New Eridu's peace"
                ]
            ]
        )
    ]
    
    func populateCharacters() async throws {
        let allCharacters = genshinCharacters + starRailCharacters + zenlessCharacters
        
        for character in allCharacters {
            let docRef = db.collection("characters").document(character.id)
            try await docRef.setData(character.asDictionary, merge: true)
            print("✅ Successfully added character: \(character.name)")
        }
        
        print("✅ All characters populated successfully!")
    }
}

// Usage:
// let populator = CharacterDataPopulator()
// try await populator.populateCharacters() 
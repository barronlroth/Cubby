# Apple’s Foundation Models in iOS 26: On‑Device AI for Emoji Suggestion & Generation

## Introduction

Apple has integrated powerful **foundation models** – large generative AI models – directly into its operating systems. First introduced as part of *Apple Intelligence* in iOS 18[\[1\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=At%20the%202024%20Worldwide%20Developers,into%20iOS%C2%A018%2C%20iPadOS%C2%A018%2C%20and%20macOS%C2%A0Sequoia), these models have since evolved and are now accessible to developers in iOS 26 via the new **Foundation Models framework**[\[2\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=The%20Foundation%20Models%20framework%20is,when%20Apple%20Intelligence%20is%20enabled)[\[3\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=,into%20a%20developer%E2%80%99s%20existing%20app). This means you can leverage Apple’s on-device AI (free of charge, with no network required) to add smart features to your apps while keeping user data private[\[4\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=With%20the%20release%20of%20iOS,metrics%2C%20developers%20have%20embraced%20the). In this guide, we’ll explore what Apple’s foundation models are and demonstrate how to use them in Xcode/Swift for a fun use-case: suggesting the most suitable emoji for a given text, and even generating custom “Genmoji” emojis on-device.

## Apple’s New Foundation Models Overview

Apple’s foundation models consist of multiple AI models specialized for everyday tasks[\[5\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=Apple%20Intelligence%20is%20comprised%20of,to%20simplify%20interactions%20across%20apps). At their core is a \~3 billion–parameter language model running on-device, tuned for a **diverse range of text tasks** – e.g. summarization, extraction, classification, dialog, and creative text generation[\[6\]](https://arxiv.org/html/2507.13575v3#:~:text=approximately%203B%20parameter%20on,we%20have%20specialized%20our%20on). There’s also a larger server-grade model (used via Apple’s Private Cloud Compute for certain features), plus specialized models for code (in Xcode) and image generation[\[7\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=In%20the%20following%20overview%2C%20we,users%20express%20themselves%20visually%2C%20for). Notably, Apple has a diffusion-based image model to **create playful images** – this powers features like Genmoji (custom emojis) and Image Playground in the Messages app[\[5\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=Apple%20Intelligence%20is%20comprised%20of,to%20simplify%20interactions%20across%20apps).

**Key characteristics** of Apple’s foundation models include:

* **On-Device Processing & Privacy:** The default 3B model runs entirely on the user’s device (iPhone, iPad, Mac, etc.), so prompts and outputs never leave the device[\[4\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=With%20the%20release%20of%20iOS,metrics%2C%20developers%20have%20embraced%20the). This aligns with Apple’s privacy-first approach – no personal data is sent to servers for model inference.

* **Offline & Free:** Because it’s on-device, your app’s AI features work without internet and incur no API costs or rate limits[\[4\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=With%20the%20release%20of%20iOS,metrics%2C%20developers%20have%20embraced%20the). This is a huge benefit over third-party cloud AI services.

* **Optimized for Apple Hardware:** The model is highly optimized for speed and efficiency on Apple Silicon (using techniques like 2–4 bit weight quantization and Neural Engine acceleration)[\[8\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=happy%20with%20the%20performance.%20,but%20first%20impressions%20are%20promising)[\[9\]](https://arxiv.org/html/2507.13575v3#:~:text=3B,experts%20sparse). In practice, developers report the on-device model performs well on modern devices (with a context window around 4096 tokens)[\[10\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=Peter%20Steinberger%20).

* **Focused Capabilities:** Unlike gigantic general-purpose models, Apple’s 3B model is tuned for practical tasks at “device scale”[\[11\]](https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441#:~:text=Apple%20introduced%20the%20Foundation%20Models,rather%20than%20world%20knowledge%20trivia). It may not have exhaustive world knowledge, but it excels at *useful* tasks like understanding and transforming user-provided text[\[6\]](https://arxiv.org/html/2507.13575v3#:~:text=approximately%203B%20parameter%20on,we%20have%20specialized%20our%20on). It can summarize text, extract structured information, classify or tag content, engage in short dialogue, and **generate or refine text** based on context[\[6\]](https://arxiv.org/html/2507.13575v3#:~:text=approximately%203B%20parameter%20on,we%20have%20specialized%20our%20on). These capabilities are perfect for enhancing app features (think smart replies, text analysis, etc.).

* **Built-in Guardrails:** Apple has baked in responsible AI measures – the system scans inputs and outputs for safety (avoiding disallowed content, PII, etc.)[\[12\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=processing%20and%20groundbreaking%20infrastructure%20like,when%20training%20our%20foundation%20models). As a developer, you get the benefits of Apple’s alignment/safety work out of the box.

In iOS 26, Apple finally opened up these models to **third-party developers** via the Foundation Models framework[\[2\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=The%20Foundation%20Models%20framework%20is,when%20Apple%20Intelligence%20is%20enabled). This framework is tightly integrated with Swift, making it *extremely easy* to use the on-device model in your own code – **as little as three lines of Swift** to get a result[\[3\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=,into%20a%20developer%E2%80%99s%20existing%20app). Let’s see how.

## Using the Foundation Models Framework (Xcode 26 & Swift)

To tap into the on-device language model, you’ll use the **FoundationModels** framework (available in iOS/iPadOS 26 and macOS 26). Start by importing the framework in your Swift code or SwiftUI project:

import FoundationModels

The primary interface is a LanguageModelSession, which represents a running session with the LLM. You can create a session and send it a prompt like so:

let session \= LanguageModelSession()  
let modelResponse \= try await session.respond(to: userInputText)  
let outputText \= modelResponse.content

That’s it – in this basic example, you pass in a string (userInputText) and the model generates a completion or answer, which you retrieve from modelResponse.content. The API is asynchronous (since generation can take some time) and uses Swift’s do/try/await pattern for error handling[\[13\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=%2F%2F%201%20let%20session%20%3D,var%20response%3A%20String)[\[14\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=Part%20of%20the%20power%20of,Here%E2%80%99s%20the%20process). In practice, this minimal code produces a full model-generated response to the input prompt. Apple’s sample shows that *just these three lines* can set up and get a reply from the foundation model[\[13\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=%2F%2F%201%20let%20session%20%3D,var%20response%3A%20String)[\[3\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=,into%20a%20developer%E2%80%99s%20existing%20app).

**Sessions and Options:** A LanguageModelSession can be stateful. You may provide **instructions or context** when initializing a session, which act like a “system prompt.” For example, you could do:

let instructions \= "You are an assistant that replies with brief answers."  
let session \= LanguageModelSession(instructions: instructions)

All prompts in this session will then obey those guidelines unless overridden. The session also maintains a transcript of the conversation if you use it for multi-turn interactions (so it can remember prior queries in the session).

You can also pass various options to respond(to:options:) – for instance, to control randomness (temperature), max tokens, etc. By default, the model might return Markdown-formatted text[\[15\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=3.%20The%20,If%20the%20model), but you can adjust or parse that as needed.

**Checking Availability:** Apple’s models only run on “Apple Intelligence” capable devices. You should guard calls with a check that the on-device model is available. The framework provides SystemLanguageModel.default.isAvailable (a Boolean) to detect this[\[16\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=struct%20Intelligence%20,return%20input). For example:

guard SystemLanguageModel.default.isAvailable else {  
    // Handle gracefully: maybe fall back or inform the user   
    return  
}

This might return false if the device or OS doesn’t support Apple Intelligence, if the user has it disabled, or if the model assets aren’t yet downloaded. (On first use, the system may need to download the model in the background – ensure the device has iOS 26+ and Apple Intelligence enabled in Settings.)

**Guided Generation & Tools:** The Foundation Models framework includes advanced features to make outputs more structured and deterministic when needed. **Guided Generation** lets you define a **Swift data structure** or format that the model should adhere to in its response[\[2\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=The%20Foundation%20Models%20framework%20is,when%20Apple%20Intelligence%20is%20enabled). For example, you can create a struct with specific fields and mark it with the @Generable macro, providing natural-language hints (@Guide) for each field. The model will then generate output parsed into that struct, guaranteeing the format is correct. This is incredibly useful for getting JSON-like responses or ensuring the model’s answer can be parsed reliably (no more brittle prompt hacks). Similarly, **Tool Calling** allows the model to call custom code (your functions) during generation to fetch information – for instance, your app can expose a “Weather lookup” tool and the model will learn to invoke it if a query needs live weather data[\[17\]](https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441#:~:text=,blend%20those%20results%20into%20answers)[\[18\]](https://arxiv.org/html/2507.13575v3#:~:text=match%20at%20L882%20Tool%20calling,the%20structural%20correctness%20of%20tool). Tool calls are also structured via guided generation, and you decide what functions (if any) to expose.

For our purposes (emoji suggestions), we may not need custom tools, but we will take advantage of guided output to get a clean emoji result.

## Using the Model to Suggest an Emoji

With the foundation model at your fingertips, a neat feature you can implement is an **emoji suggestion**: given a text string (say, a message or status), have the AI pick an emoji that best fits the text’s sentiment or context. This is a fun way to spice up communications – e.g. user types “Wow, I just got a promotion\!” and your app could suggest a 🎉 emoji.

### Basic Prompting Method

The simplest approach is to **prompt the model** in plain English to give you an emoji. For example, you could send a prompt like:

*"Suggest an emoji that best represents the following text: {user text}"*

However, if you do this naively, the model might return a full sentence (e.g. *"The 😊 emoji would fit best."*). To nudge it towards just giving the emoji, you can craft the prompt explicitly, or use the session’s instructions. For instance:

let instructions \= "You are an assistant that replies only with a single emoji that fits the user's text."  
let session \= LanguageModelSession(instructions: instructions)  
let modelResponse \= try await session.respond(to: userText)  
let emoji \= modelResponse.content

Now, if userText \= "I got a promotion at work\!", the model (following the instruction) might output: “🎉”. If the user text is "That's hilarious", it might return "😂", and so on. Since the foundation model understands sentiment and context quite well, it can infer an appropriate emoji in many cases. In fact, the model has been fine-tuned for “text understanding” and even **content tagging/classification** tasks[\[6\]](https://arxiv.org/html/2507.13575v3#:~:text=approximately%203B%20parameter%20on,we%20have%20specialized%20our%20on), so it can recognize the tone of a message (happy, sad, sarcastic, etc.) and choose a fitting emoji.

### Ensuring a Correct Emoji Output (Guided Generation)

To be more confident that we get *only* an emoji (and not extra text), we can leverage **guided generation** with a custom output type. For example, define a simple Swift struct to represent the model’s response:

@Generable  
struct EmojiSuggestion {  
    @Guide(description: "A single emoji character that best represents the input text.")  
    var emoji: String  
}

Here, we annotate the struct with @Generable (making it eligible for model generation) and the field emoji with a guide description. This description (which can be phrased naturally) tells the model what we expect: *“a single emoji character that best represents the input.”* Now we can call the model with this structured guidance:

let session \= LanguageModelSession()  
let result \= try await session.respond(to: userText, generating: EmojiSuggestion.self)  
let emoji \= result.content.emoji

By using the generating: EmojiSuggestion.self parameter, the framework instructs the model to output data conforming to our EmojiSuggestion structure[\[19\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=func%20generateRecipe,)[\[20\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=%40Generable%20struct%20Recipe%20,let%20title%3A%20String). Under the hood, the model will format its answer in a way that can be parsed into the struct (likely as JSON or similar), and the framework will parse it for you. The end result is that emoji will contain exactly one emoji character (if the model followed the guide correctly). This approach provides a **type-safe, predictable output**[\[21\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=In%20order%20to%20receive%20response,use%20to%20annotate%20our%20type) – crucial in production apps. No more guessing if the model’s text can be parsed; the framework guarantees it matches the schema.

### Example

Suppose userText \= "I am so excited to see you\!". With guided generation as above, the model might return an EmojiSuggestion whose emoji is "🤗" (hug emoji, indicating excitement/affection). If the text were "I'm feeling a bit down...", it might choose "😔". The beauty is that all this logic – understanding the text’s sentiment and mapping it to an emoji – is handled by the foundation model’s language understanding abilities. Your code remains simple.

*Tip:* You can experiment with prompts in an Xcode Playground to see how the model responds[\[22\]](https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441#:~:text=What%20you%20can%20use%20right,away). Apple’s integration even allows quick iterations in Playgrounds or the debugging console, so you can refine your instruction prompt or guide descriptions for best results.

## On-Device Emoji Generation with Genmoji

Suggesting an existing emoji is great, but what if you want to **create new emoji**? Apple’s AI can do that too – introducing *Genmoji*. **Genmoji** is Apple’s feature for generating custom emoji-style stickers using generative AI. Essentially, it’s an on-device image generation model (a diffusion model) that can create unique, personalized emojis based on a description or by mixing elements of existing emojis[\[23\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=Genmoji%20and%20Image%20Playground%20provide,match%20their%20friend%E2%80%99s%20latest%20look)[\[24\]](https://developer.apple.com/apple-intelligence/#:~:text=Now%20you%20can%20enhance%20your,inspired%20by%20family%20and%20friends).

For example, a user could type *“blue happy face with sunglasses”* and get a brand new emoji graphic matching that idea. Or they could take two existing emoji (say, “🤠” and “🤖”) and **mix** them with a prompt like “cowboy robot” to get a Wild West style robot face. Genmoji even lets users generate emojis inspired by real people – e.g. *“my friend Alice smiling with a party hat”* might produce a cartoon emoji resembling Alice[\[25\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=themselves,match%20their%20friend%E2%80%99s%20latest%20look).

From a developer’s perspective, Apple provides the **Image Playground** APIs to do image generation. There’s a dedicated ImageCreator API that allows apps to **programmatically create images using the on-device model**[\[26\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=The%20,4%20or%20higher). This is part of Apple’s Vision or Intelligence frameworks (you’ll import ImagePlayground to use it). Just like the language model, image generation is done on-device and privately.

### Using the ImageCreator API

To generate an emoji (or any image) via code, you need three inputs: a **prompt**, a **style**, and the **number of images** to produce[\[27\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=To%20generate%20images%2C%20we%20need,to%20provide%20three%20parameters). Apple’s API encapsulates these in a few types:

* **ImagePlaygroundConcept:** Represents the *concept or prompt* for the image. You can create a concept from text (.text("...")), from an existing image (.image(someCGImage)), or even from a drawing or a long text with a title[\[28\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=There%20are%20different%20solutions%20for,providing%20the%20prompt). For an emoji, a simple text concept usually suffices (e.g. .text("cute laughing cat emoji")). You can also combine multiple concepts in an array – e.g. one text concept and one image concept – to mix ideas (this is how you’d blend existing emoji images with text descriptions).

* **ImagePlaygroundStyle:** Specifies the visual style for the output[\[29\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=The%20). iOS 26 offers a few presets: .animation (a 3D animated movie-like style, likely similar to Apple’s 3D emoji style), .illustration (a flat 2D illustration style), and .sketch (hand-drawn look)[\[30\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=Currently%2C%20the%20following%20styles%20are,available). For emoji, “illustration” is a good choice to get a clean 2D graphic; “animation” might produce a more detailed 3D-rendered emoji.

* **ImageCreator:** The object that orchestrates generation. You initialize it (this may load the model if not already), then call its images(for: \[Concept\], style: Style, limit: N) method to actually generate images[\[31\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=Now%20let%27s%20use%20the%20ImageCreator,that%20needs%20to%20be%20generated)[\[32\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=do%20,animation). The result is an async sequence of up to N images.

Let’s write a quick example that generates one custom emoji image from a text description:

import ImagePlayground

// Ensure device supports image generation (iOS 18.4+ on compatible hardware)\[26\]  
let imageCreator \= try await ImageCreator()  // might throw if not supported  
let concepts: \[ImagePlaygroundConcept\] \= \[.text("a happy sun with sunglasses emoji")\]  
let style: ImagePlaygroundStyle \= .illustration

// Request image generation  
let imageSequence \= try await imageCreator.images(for: concepts, style: style, limit: 1\)

// The API returns an async sequence; we can iterate to get generated images:  
var generatedEmojiImage: CGImage?  
for try await image in imageSequence {  
    generatedEmojiImage \= image.cgImage  // take the CGImage (you could convert to UIImage for UI use)  
}

In this code, we ask the model for one image of “a happy sun with sunglasses emoji” in illustration style. After a brief moment, generatedEmojiImage will hold a CGImage of the AI-created emoji 🌞😎 (a sun with sunglasses). You could then display it in a UIImageView or as an Image in SwiftUI. If you request multiple images (by setting limit: N), the model will produce N variants – you might then present a carousel for the user to pick their favorite.

**Mixing Emoji with Descriptions:** Suppose we want to create an emoji inspired by two existing ones – e.g. combine 🤖 (robot) and 🤠 (cowboy) into a “cowboy robot” emoji. If you have images for those (perhaps by rendering the emoji characters to CGImage), you can do:

let robotImg \= CGImageFromEmoji("🤖")  
let cowboyImg \= CGImageFromEmoji("🤠")  
let concepts: \[ImagePlaygroundConcept\] \= \[  
    .image(robotImg), .image(cowboyImg),  
    .text("cowboy robot face emoji")  
\]  
...

Mixing concept images with text prompt guides the model to incorporate visual elements of the given images (robot, cowboy hat) while following the text description. Apple specifically supports this workflow – users can pick favorite emoji and add a description to create something new[\[23\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=Genmoji%20and%20Image%20Playground%20provide,match%20their%20friend%E2%80%99s%20latest%20look). The result might be a robot face wearing a cowboy hat. Likewise, to create an emoji of a friend, you could use .image(friendPhoto) plus a text like “smiling face emoji of \[Friend’s name\]” to guide the style (Apple notes you can generate Genmoji inspired by people in your Photos library)[\[25\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=themselves,match%20their%20friend%E2%80%99s%20latest%20look).

**Note:** The image generation model is heavy; in practice Apple initially limited Genmoji to certain high-end devices (e.g. iPhone 15 Pro/Max and iPhone 16 series)[\[33\]](https://www.tomsguide.com/ai/i-tried-creating-genmoji-with-apple-intelligence-heres-what-i-like-and-what-went-wrong#:~:text=So%20when%20I%20discovered%20that,and%20all%20iPhone%2016%20models), likely due to hardware requirements. Ensure you test on a supported device and handle the ImageCreator.Error.notSupported error which is thrown if the device can’t do image creation[\[34\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=This%20are%20all%20the%20possible,the%20ImageCreator%20object%20can%20return)[\[32\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=do%20,animation). Also, make sure **Apple Intelligence is enabled** on the device, and that the necessary image model assets are downloaded (the system may handle this if the user has used Image Playground or if you prompt the API, but you might need to guide them to enable it in Settings if off).

### Using Genmoji in Apps

The good news is if you use standard system UI components, **Genmoji might be available with no extra code**. For example, in a UITextField or SwiftUI TextField, the system emoji keyboard now includes Genmoji functionality[\[24\]](https://developer.apple.com/apple-intelligence/#:~:text=Now%20you%20can%20enhance%20your,inspired%20by%20family%20and%20friends). Users can tap an “\[+\]” or similar option to create a Genmoji by typing a description or mixing emoji right from the keyboard. Those Genmoji will come through as stickers/images that you can display just like emoji. Apple notes that **Genmoji are automatically supported as stickers in your app when using system text controls**[\[35\]](https://developer.apple.com/apple-intelligence/#:~:text=themselves%20in%20the%20moment%20while,inspired%20by%20family%20and%20friends) – so a chat app using UITextView for input gains Genmoji support out of the box in iOS 26\.

If you want more control (say you have a custom text editor, or you want to trigger Genmoji generation in a non-text context), you’d use the **ImageCreator API** as shown above. Apple’s frameworks let you render the resulting images and even integrate them as inline attachments or custom reactions (they behave like stickers/Tapbacks in Messages)[\[36\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=,or%20reaction%20in%20a%20Tapback).

## Putting It All Together

With Apple’s foundation models, implementing on-device AI features is easier than ever for iOS developers. We covered how to use the Foundation Models framework’s language model to interpret text and suggest a fitting emoji in just a few lines of code. This leverages the model’s understanding of language and tone to add a playful, personalized touch to your app’s user experience. The same on-device model can handle countless other tasks – from summarizing content to answering questions – all privately and offline[\[4\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=With%20the%20release%20of%20iOS,metrics%2C%20developers%20have%20embraced%20the).

We also explored Genmoji and image generation, powered by Apple’s on-device diffusion models. With the Image Playground APIs, you can create brand-new emojis (or any stylized images) on the fly, unlocking creative features that were science fiction just a few years ago. For instance, you might let users “emoji-fy” themselves or generate an emoji based on the mood of a message – directly on their device, no server needed.

**Considerations:** Keep in mind that these capabilities require iOS 26 (or the corresponding macOS/iPadOS versions) and compatible hardware. Always check for availability and provide fallback behaviors for users on older devices/OS. Performance is generally good thanks to Apple’s optimizations, but for very large or streaming outputs you may need to manage UI updates (the framework does support streaming token-by-token if you need it, though for a single emoji this isn’t a concern). And while Apple’s guardrails handle many safety issues, it’s wise to test the model outputs especially for open-ended prompts, to ensure the results align with your app’s context and content guidelines.

## Conclusion

Apple’s foray into on-device AI with foundation models is a game-changer for iOS developers. It brings the power of generative text and image AI into our apps with unprecedented ease and privacy. In iOS 26, we can integrate a 3B-parameter language model with just a few lines of Swift and no 3rd-party libraries[\[3\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=,into%20a%20developer%E2%80%99s%20existing%20app), and we can generate custom emoji stickers with a few API calls. In this report, we focused on emoji suggestions and generation as a glimpse of what’s possible. The same tools can be applied to countless other simple or complex features – from intelligent search and creative content generation to personal assistants and beyond – all on-device. Apple’s Foundation Models framework truly “unlocks new intelligent app experiences,” empowering developers to build features that feel magical while respecting user privacy[\[2\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=The%20Foundation%20Models%20framework%20is,when%20Apple%20Intelligence%20is%20enabled)[\[4\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=With%20the%20release%20of%20iOS,metrics%2C%20developers%20have%20embraced%20the).

With this foundation, you’re ready to experiment. Try out the emoji suggestion in your app, and consider offering users the option to craft their perfect Genmoji. Even a small touch like an apt emoji or a fun custom sticker can delight users – and now the intelligence behind it lives in their pocket. Happy coding with on-device AI\! 🚀

## Sources

* Apple Machine Learning Research: *“Introducing Apple’s On-Device and Server Foundation Models.”* (June 2024\)[\[1\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=At%20the%202024%20Worldwide%20Developers,into%20iOS%C2%A018%2C%20iPadOS%C2%A018%2C%20and%20macOS%C2%A0Sequoia)[\[5\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=Apple%20Intelligence%20is%20comprised%20of,to%20simplify%20interactions%20across%20apps)

* Apple AI/ML Tech Report: *“Apple Intelligence Foundation Language Models.”* (arXiv preprint 2025\)[\[6\]](https://arxiv.org/html/2507.13575v3#:~:text=approximately%203B%20parameter%20on,we%20have%20specialized%20our%20on)

* Apple Newsroom: *“Apple’s Foundation Models framework unlocks new intelligent app experiences.”* (Sep 29, 2025\)[\[2\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=The%20Foundation%20Models%20framework%20is,when%20Apple%20Intelligence%20is%20enabled)[\[4\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=With%20the%20release%20of%20iOS,metrics%2C%20developers%20have%20embraced%20the)

* Michael Tsai Blog: WWDC 2025 coverage of Foundation Models framework[\[3\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=,into%20a%20developer%E2%80%99s%20existing%20app)[\[8\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=happy%20with%20the%20performance.%20,but%20first%20impressions%20are%20promising)

* Kodeco Tutorial: *“Using Apple Foundation Models.”* (Oct 2025\) – sample code for LanguageModelSession usage[\[13\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=%2F%2F%201%20let%20session%20%3D,var%20response%3A%20String)

* Swift with Majid: *“Building AI features using Foundation Models (Structured Content).”* (Aug 2025\)[\[19\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=func%20generateRecipe,)[\[21\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=In%20order%20to%20receive%20response,use%20to%20annotate%20our%20type)

* Apple Developer Documentation: *Apple Intelligence – Genmoji overview*[\[24\]](https://developer.apple.com/apple-intelligence/#:~:text=Now%20you%20can%20enhance%20your,inspired%20by%20family%20and%20friends)

* Apple Newsroom: *“Apple Intelligence gets even more powerful with new capabilities across Apple devices.”* (Jun 2025\)[\[23\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=Genmoji%20and%20Image%20Playground%20provide,match%20their%20friend%E2%80%99s%20latest%20look)

* Create with Swift: *“Generating images programmatically with Image Playground.”* (Feb 2025\)[\[26\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=The%20,4%20or%20higher)[\[32\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=do%20,animation)

---

[\[1\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=At%20the%202024%20Worldwide%20Developers,into%20iOS%C2%A018%2C%20iPadOS%C2%A018%2C%20and%20macOS%C2%A0Sequoia) [\[5\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=Apple%20Intelligence%20is%20comprised%20of,to%20simplify%20interactions%20across%20apps) [\[7\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=In%20the%20following%20overview%2C%20we,users%20express%20themselves%20visually%2C%20for) [\[12\]](https://machinelearning.apple.com/research/introducing-apple-foundation-models#:~:text=processing%20and%20groundbreaking%20infrastructure%20like,when%20training%20our%20foundation%20models) Introducing Apple’s On-Device and Server Foundation Models \- Apple Machine Learning Research

[https://machinelearning.apple.com/research/introducing-apple-foundation-models](https://machinelearning.apple.com/research/introducing-apple-foundation-models)

[\[2\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=The%20Foundation%20Models%20framework%20is,when%20Apple%20Intelligence%20is%20enabled) [\[4\]](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/#:~:text=With%20the%20release%20of%20iOS,metrics%2C%20developers%20have%20embraced%20the) Apple’s Foundation Models framework unlocks new intelligent app experiences \- Apple

[https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/](https://www.apple.com/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/)

[\[3\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=,into%20a%20developer%E2%80%99s%20existing%20app) [\[8\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=happy%20with%20the%20performance.%20,but%20first%20impressions%20are%20promising) [\[10\]](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/#:~:text=Peter%20Steinberger%20) Michael Tsai \- Blog \- Foundation Models Framework

[https://mjtsai.com/blog/2025/06/17/foundation-models-framework/](https://mjtsai.com/blog/2025/06/17/foundation-models-framework/)

[\[6\]](https://arxiv.org/html/2507.13575v3#:~:text=approximately%203B%20parameter%20on,we%20have%20specialized%20our%20on) [\[9\]](https://arxiv.org/html/2507.13575v3#:~:text=3B,experts%20sparse) [\[18\]](https://arxiv.org/html/2507.13575v3#:~:text=match%20at%20L882%20Tool%20calling,the%20structural%20correctness%20of%20tool) Apple Intelligence Foundation Language Models

[https://arxiv.org/html/2507.13575v3](https://arxiv.org/html/2507.13575v3)

[\[11\]](https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441#:~:text=Apple%20introduced%20the%20Foundation%20Models,rather%20than%20world%20knowledge%20trivia) [\[17\]](https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441#:~:text=,blend%20those%20results%20into%20answers) [\[22\]](https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441#:~:text=What%20you%20can%20use%20right,away) Foundation Models framework on iOS 26: a simple guide to Guided Generation, Streaming, and Tool Calling | by Himali Marasinghe | Oct, 2025 | Medium

[https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441](https://medium.com/@himalimarasinghe/foundation-models-framework-on-ios-26-a-simple-guide-to-guided-generation-streaming-and-tool-3bdbb1374441)

[\[13\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=%2F%2F%201%20let%20session%20%3D,var%20response%3A%20String) [\[14\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=Part%20of%20the%20power%20of,Here%E2%80%99s%20the%20process) [\[15\]](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03#:~:text=3.%20The%20,If%20the%20model) Using Foundation Models | Kodeco

[https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03](https://www.kodeco.com/ios/paths/apple-ai-models/48744203-apple-foundation-models/01-introduction-to-using-apple-foundation-models/03)

[\[16\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=struct%20Intelligence%20,return%20input) [\[19\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=func%20generateRecipe,) [\[20\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=%40Generable%20struct%20Recipe%20,let%20title%3A%20String) [\[21\]](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/#:~:text=In%20order%20to%20receive%20response,use%20to%20annotate%20our%20type) Building AI features using Foundation Models. Structured Content. | Swift with Majid

[https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/](https://swiftwithmajid.com/2025/08/26/building-ai-features-using-foundation-models-structured-content/)

[\[23\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=Genmoji%20and%20Image%20Playground%20provide,match%20their%20friend%E2%80%99s%20latest%20look) [\[25\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=themselves,match%20their%20friend%E2%80%99s%20latest%20look) [\[36\]](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/#:~:text=,or%20reaction%20in%20a%20Tapback) Apple Intelligence gets even more powerful with new capabilities \- Apple (GQ)

[https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/](https://www.apple.com/gq/newsroom/2025/06/apple-intelligence-gets-even-more-powerful-with-new-capabilities-across-apple-devices/)

[\[24\]](https://developer.apple.com/apple-intelligence/#:~:text=Now%20you%20can%20enhance%20your,inspired%20by%20family%20and%20friends) [\[35\]](https://developer.apple.com/apple-intelligence/#:~:text=themselves%20in%20the%20moment%20while,inspired%20by%20family%20and%20friends) Apple Intelligence \- Apple Developer

[https://developer.apple.com/apple-intelligence/](https://developer.apple.com/apple-intelligence/)

[\[26\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=The%20,4%20or%20higher) [\[27\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=To%20generate%20images%2C%20we%20need,to%20provide%20three%20parameters) [\[28\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=There%20are%20different%20solutions%20for,providing%20the%20prompt) [\[29\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=The%20) [\[30\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=Currently%2C%20the%20following%20styles%20are,available) [\[31\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=Now%20let%27s%20use%20the%20ImageCreator,that%20needs%20to%20be%20generated) [\[32\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=do%20,animation) [\[34\]](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/#:~:text=This%20are%20all%20the%20possible,the%20ImageCreator%20object%20can%20return) Generating images programmatically with Image Playground

[https://www.createwithswift.com/generating-images-programmatically-with-image-playground/](https://www.createwithswift.com/generating-images-programmatically-with-image-playground/)

[\[33\]](https://www.tomsguide.com/ai/i-tried-creating-genmoji-with-apple-intelligence-heres-what-i-like-and-what-went-wrong#:~:text=So%20when%20I%20discovered%20that,and%20all%20iPhone%2016%20models) I tried creating Genmoji with Apple Intelligence — here's what I like and what went wrong | Tom's Guide

[https://www.tomsguide.com/ai/i-tried-creating-genmoji-with-apple-intelligence-heres-what-i-like-and-what-went-wrong](https://www.tomsguide.com/ai/i-tried-creating-genmoji-with-apple-intelligence-heres-what-i-like-and-what-went-wrong)
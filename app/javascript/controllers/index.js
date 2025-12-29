// Import and register all controllers
import { application } from "controllers/application"

import DropdownController from "controllers/dropdown_controller"
import FlashController from "controllers/flash_controller"
import SecretRevealController from "controllers/secret_reveal_controller"
import ClipboardController from "controllers/clipboard_controller"
import SearchController from "controllers/search_controller"

application.register("dropdown", DropdownController)
application.register("flash", FlashController)
application.register("secret-reveal", SecretRevealController)
application.register("clipboard", ClipboardController)
application.register("search", SearchController)

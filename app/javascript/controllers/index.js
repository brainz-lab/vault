// Import and register all controllers
import { application } from "./application"

import DropdownController from "./dropdown_controller"
import FlashController from "./flash_controller"
import SecretRevealController from "./secret_reveal_controller"
import ClipboardController from "./clipboard_controller"
import SearchController from "./search_controller"

application.register("dropdown", DropdownController)
application.register("flash", FlashController)
application.register("secret-reveal", SecretRevealController)
application.register("clipboard", ClipboardController)
application.register("search", SearchController)

import { i18n } from "discourse-i18n";

export default <template>
  {{#if @outletArgs.user.geoip}}
    <div class="user-card-post-names-outlet post-geoip-metadata" ...attributes>
      {{#if @outletArgs.user.geoip.ip}}
        <span class="post-geoip-metadata__item">
          <span class="desc">{{i18n "discourse_post_geoip.ip"}}</span>
          {{@outletArgs.user.geoip.ip}}
        </span>
      {{/if}}
      {{#if @outletArgs.user.geoip.location}}
        <span class="post-geoip-metadata__item">
          <span class="desc">{{i18n "discourse_post_geoip.location"}}</span>
          {{@outletArgs.user.geoip.location}}
        </span>
      {{/if}}
    </div>
  {{/if}}
</template>

import { i18n } from "discourse-i18n";

export default <template>
  {{#if @outletArgs.model.geoip}}
    <div class="post-geoip-metadata user-profile-geoip" ...attributes>
      {{#if @outletArgs.model.geoip.ip}}
        <span class="post-geoip-metadata__item">
          <span class="desc">{{i18n "discourse_post_geoip.ip"}}</span>
          {{@outletArgs.model.geoip.ip}}
        </span>
      {{/if}}
      {{#if @outletArgs.model.geoip.location}}
        <span class="post-geoip-metadata__item">
          <span class="desc">{{i18n "discourse_post_geoip.location"}}</span>
          {{@outletArgs.model.geoip.location}}
        </span>
      {{/if}}
    </div>
  {{/if}}
</template>

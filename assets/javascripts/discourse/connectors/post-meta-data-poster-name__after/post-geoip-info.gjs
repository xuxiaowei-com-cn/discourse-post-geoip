import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class PostGeoipInfo extends Component {
  get geoip() {
    return this.args.outletArgs?.post?.geoip;
  }

  <template>
    {{#if this.geoip}}
      <div class="post-geoip-info">
        {{#if this.geoip.ip}}
          <span class="post-geoip-info__item">
            <span class="post-geoip-info__label">{{i18n
                "discourse_post_geoip.ip"
              }}</span>
            {{this.geoip.ip}}
          </span>
        {{/if}}
        {{#if this.geoip.location}}
          <span class="post-geoip-info__item">
            <span class="post-geoip-info__label">{{i18n
                "discourse_post_geoip.location"
              }}</span>
            {{this.geoip.location}}
          </span>
        {{/if}}
      </div>
    {{/if}}
  </template>
}

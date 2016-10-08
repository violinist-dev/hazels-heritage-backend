<?php
namespace ataylorme\recipe_endpoints;

/**
 * Register recipe REST endpoints
 */
function register_api_hooks() {
	$namespace = 'recipes/v1';

	register_rest_route( $namespace, '/list-recipes/', array(
		'methods'  => 'GET',
		'callback' => __NAMESPACE__ . '\list_recipes',
	) );

}

add_action( 'rest_api_init', __NAMESPACE__ . '\register_api_hooks' );

function list_recipes() {
	delete_transient( 'recipes_list' );
	if ( 0 || false === ( $return = get_transient( 'recipes_list' ) ) ) {
		$args = array(
			'post_type'      => 'recipe',
			'post_status'    => 'publish',
			'posts_per_page' => 25,
			'nopaging'       => true
		);

		$the_query = new \WP_Query( $args );

		$return = array(
			'count'   => 0,
			'recipes' => array(),
		);

		if ( $the_query->have_posts() ):
			$return['count'] = (int) $the_query->post_count;
			while ( $the_query->have_posts() ):
				$the_query->the_post();
				$post_id = get_the_ID();

				$desc = get_post_meta( $post_id, 'recipe_desc', true );
				$desc = ( empty( $desc ) ) ? false : $desc;

				$type = wp_get_post_terms( $post_id, 'recipe_type' );
				$type = ( empty( $type ) ) ? false : $type;
				if ( is_array( $type ) && 1 === count( $type ) ) {
					$type = $type[0];
				}

				$main_ingredient = wp_get_post_terms( $post_id, 'recipe_main_ingredient' );
				$main_ingredient = ( empty( $main_ingredient ) ) ? false : $main_ingredient;
				if ( is_array( $main_ingredient ) && 1 === count( $main_ingredient ) ) {
					$main_ingredient = $main_ingredient[0];
				}

				$return['recipes'][] = array(
					'ID'              => $post_id,
					'title'           => get_the_title( $post_id ),
					'desc'            => $desc,
					'type'            => $type,
					'main_ingredient' => $main_ingredient,
				);

			endwhile;

			wp_reset_postdata();

		endif;

		// cache for 10 minutes
		set_transient( 'recipes_list', $return, apply_filters( 'posts_ttl', 60 * 10 ) );
	}

	$response = new \WP_REST_Response( $return );

	$response->header( 'Access-Control-Allow-Origin', apply_filters( 'access_control_allow_origin', '*' ) );

	return $response;
}